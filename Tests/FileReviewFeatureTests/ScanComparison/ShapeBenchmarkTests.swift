import Foundation
import StorageFixCore
import StorageMapFeature
import Testing

/// Opt-in (STORAGEFIX_BENCHMARK=1) generated fixtures for the remaining Milestone 6 shapes:
/// deep nesting, a large flat folder and duplicate-heavy content. Only the generated tree is deleted.
@MainActor struct ShapeBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_BENCHMARK"] == "1"))
    func `Record deep, large-flat and duplicate-heavy baselines`() async throws {
        let parent = FileManager.default.temporaryDirectory.appending(path: "StorageFix-Shapes-\(UUID())")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }
        var results: [ShapeResult] = []
        results.append(try await deep(parent.appending(path: "deep"), depth: 60, filesPerLevel: 20))
        results.append(try await flat(parent.appending(path: "flat"), count: 50_000))
        results.append(try await duplicates(parent.appending(path: "duplicates"), groups: 200, copies: 10, bytes: 262_144))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(results)
        if let output = ProcessInfo.processInfo.environment["STORAGEFIX_SHAPES_OUTPUT"] { try data.write(to: URL(fileURLWithPath: output)) }
        print(String(decoding: data, as: UTF8.self))
    }

    private func deep(_ root: URL, depth: Int, filesPerLevel: Int) async throws -> ShapeResult {
        var folder = root
        for level in 0..<depth {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for index in 0..<filesPerLevel { try Data([1, 2, 3, 4]).write(to: folder.appending(path: "f-\(level)-\(index).dat")) }
            folder = folder.appending(path: "level-\(level + 1)")
        }
        let (scan, durations) = try await inventory(root, expected: depth * filesPerLevel)
        let vm = StorageMapViewModel(root: scan.root, service: FileInventoryService(source: LocalInventoryMetadataSource()))
        vm.acceptInventory(scan)
        var navigation: [Double] = []
        while let next = vm.items.first(where: \.isFolder) {
            let start = DispatchTime.now().uptimeNanoseconds
            vm.enter(next)
            navigation.append(milliseconds(since: start))
        }
        #expect(navigation.count == depth - 1)
        return ShapeResult(shape: "deep \(depth) levels × \(filesPerLevel) files", files: scan.files.count,
            scanMilliseconds: durations, navigationMilliseconds: navigation, hashingMilliseconds: [])
    }

    private func flat(_ root: URL, count: Int) async throws -> ShapeResult {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        for index in 0..<count { try Data([1, 2, 3, 4]).write(to: root.appending(path: "file-\(index).dat")) }
        let (scan, durations) = try await inventory(root, expected: count)
        let vm = StorageMapViewModel(root: scan.root, service: FileInventoryService(source: LocalInventoryMetadataSource()))
        let start = DispatchTime.now().uptimeNanoseconds
        vm.acceptInventory(scan)
        #expect(vm.totalBytes == scan.logicalBytes)
        return ShapeResult(shape: "flat \(count) files", files: scan.files.count, scanMilliseconds: durations,
            navigationMilliseconds: [milliseconds(since: start)], hashingMilliseconds: [])
    }

    private func duplicates(_ root: URL, groups: Int, copies: Int, bytes: Int) async throws -> ShapeResult {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        for group in 0..<groups {
            var content = [UInt8](repeating: UInt8(group % 251), count: bytes)
            content[bytes / 2] = UInt8(group / 251)
            for copy in 0..<copies { try Data(content).write(to: root.appending(path: "g\(group)-c\(copy).bin")) }
        }
        let (scan, durations) = try await inventory(root, expected: groups * copies)
        var hashing: [Double] = []
        for _ in 0..<3 {
            let start = DispatchTime.now().uptimeNanoseconds
            let found = try await FileSystemDuplicateService(roots: [root]).scan()
            hashing.append(milliseconds(since: start))
            #expect(found.count == groups && found.allSatisfy { $0.duplicates.count == copies - 1 })
        }
        return ShapeResult(shape: "duplicate-heavy \(groups) groups × \(copies) copies × \(bytes) bytes", files: scan.files.count,
            scanMilliseconds: durations, navigationMilliseconds: [], hashingMilliseconds: hashing)
    }

    private func inventory(_ root: URL, expected: Int) async throws -> (InventoryScan, [Double]) {
        let service = FileInventoryService(source: LocalInventoryMetadataSource())
        var durations: [Double] = [], latest: InventoryScan?
        for _ in 0..<3 {
            let start = DispatchTime.now().uptimeNanoseconds
            let scan = try await service.inventory(in: root, options: InventoryOptions(), sessionID: UUID()) { _ in }
            durations.append(milliseconds(since: start))
            #expect(scan.files.count == expected && !scan.wasCancelled)
            latest = scan
        }
        return (try #require(latest), durations)
    }

    private func milliseconds(since start: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
}

private struct ShapeResult: Encodable {
    let shape: String
    let files: Int
    let scanMilliseconds: [Double]
    let navigationMilliseconds: [Double]
    let hashingMilliseconds: [Double]
}
