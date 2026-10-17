import Darwin
import Foundation
import StorageFixCore
import StorageMapFeature
import Testing

/// Opt-in generated fixtures only. Timings include filesystem caches; no personal folders are scanned.
@MainActor struct LocalPerformanceBaselineTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_BENCHMARK"] == "1"))
    func `Record local metadata and cached navigation baseline`() async throws {
        let parent = FileManager.default.temporaryDirectory.appending(path: "StorageFix-Benchmark-\(UUID())")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }
        var results: [BaselineResult] = []
        for count in [10_000, 100_000] {
            let root = parent.appending(path: "\(count)")
            try makeFixture(root: root, count: count)
            results.append(try await measure(root: root, count: count))
            try FileManager.default.removeItem(at: root)
        }
        let report = BaselineReport(os: ProcessInfo.processInfo.operatingSystemVersionString,
            processors: ProcessInfo.processInfo.processorCount, physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            peakResidentBytes: peakMemory(), results: results)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        if let output = ProcessInfo.processInfo.environment["STORAGEFIX_BENCHMARK_OUTPUT"] { try data.write(to: URL(fileURLWithPath: output)) }
        print(String(decoding: data, as: UTF8.self))
    }
    private func makeFixture(root: URL, count: Int) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let directories = count == 100_000 ? 100 : 1
        for directory in 0..<directories {
            let folder = directories == 1 ? root : root.appending(path: "folder-\(directory)")
            if folder != root { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false) }
            for index in 0..<(count / directories) {
                try Data([1, 2, 3, 4]).write(to: folder.appending(path: "file-\(index).dat"))
            }
        }
    }
    private func measure(root: URL, count: Int) async throws -> BaselineResult {
        let service = FileInventoryService(source: LocalInventoryMetadataSource())
        var durations: [Double] = [], firstProgress: [Double] = []
        var latest: InventoryScan?
        for _ in 0..<3 {
            let probe = ProgressProbe(), start = DispatchTime.now().uptimeNanoseconds
            let scan = try await service.inventory(in: root, options: InventoryOptions(), sessionID: UUID()) { update in
                if update.fileCount > 0 { probe.record() }
            }
            durations.append(milliseconds(since: start)); firstProgress.append(probe.milliseconds(since: start))
            #expect(scan.files.count == count && scan.logicalBytes == Int64(count * 4) && !scan.wasCancelled)
            latest = scan
        }
        let scan = try #require(latest)
        let navigation = measureNavigation(scan: scan, service: service)
        let cancellation = try await measureCancellation(root: root, service: service)
        return BaselineResult(fileCount: count, layout: count == 100_000 ? "100 folders × 1000 files" : "flat",
            metadataMilliseconds: durations, firstUsefulProgressMilliseconds: firstProgress,
            cachedNavigationMilliseconds: navigation, cancellationMilliseconds: cancellation)
    }
    private func measureNavigation(scan: InventoryScan, service: any FileInventoryServiceProtocol) -> [Double] {
        let vm = StorageMapViewModel(root: scan.root, service: service)
        vm.acceptInventory(scan)
        var durations: [Double] = []
        for _ in 0..<30 {
            let start = DispatchTime.now().uptimeNanoseconds
            if let folder = vm.items.first(where: \.isFolder) { vm.enter(folder); vm.back() }
            else { vm.returnToRoot() }
            durations.append(milliseconds(since: start))
            #expect(vm.totalBytes == scan.logicalBytes)
        }
        return durations
    }
    private func measureCancellation(root: URL, service: any FileInventoryServiceProtocol) async throws -> Double {
        let probe = ProgressProbe()
        let task = Task { try await service.inventory(in: root, options: InventoryOptions(), sessionID: UUID()) { update in
            if update.fileCount > 0 { probe.record() }
        } }
        while !probe.hasProgress { await Task.yield() }
        let start = DispatchTime.now().uptimeNanoseconds
        task.cancel()
        let scan = try await task.value
        #expect(scan.wasCancelled)
        return milliseconds(since: start)
    }
    private func milliseconds(since start: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
    private func peakMemory() -> Int64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return Int64(usage.ru_maxrss)
    }
}
private struct BaselineReport: Encodable {
    let os: String
    let processors: Int
    let physicalMemoryBytes: UInt64
    let peakResidentBytes: Int64
    let results: [BaselineResult]
}
private struct BaselineResult: Encodable {
    let fileCount: Int
    let layout: String
    let metadataMilliseconds: [Double]
    let firstUsefulProgressMilliseconds: [Double]
    let cachedNavigationMilliseconds: [Double]
    let cancellationMilliseconds: Double
}
/// A synchronous scanner callback records one monotonic timestamp under a lock.
private final class ProgressProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var first: UInt64?
    var hasProgress: Bool { lock.withLock { first != nil } }
    func record() { lock.withLock { if first == nil { first = DispatchTime.now().uptimeNanoseconds } } }
    func milliseconds(since start: UInt64) -> Double { lock.withLock { first.map { Double($0 - start) / 1_000_000 } ?? -1 } }
}
