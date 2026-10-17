import Foundation
import StorageFixCore
import Testing

struct ScanSnapshotTests {
    private func scan(_ files: [DuplicateFile], root: String = "/fixture", options: InventoryOptions = InventoryOptions(),
                      coverage: InventoryCoverage = InventoryCoverage(), cancelled: Bool = false) -> InventoryScan {
        InventoryScan(sessionID: UUID(), root: URL(fileURLWithPath: root), options: options, files: files,
                      coverage: coverage, wasCancelled: cancelled)
    }
    @Test func `Snapshot round trip preserves metadata and comparison reconciles observed totals`() async throws {
        let service = ScanSnapshotService(), date = Date(timeIntervalSince1970: 100.123456)
        let before = try await service.capture(scan([DuplicateFile(path: "/fixture/same", bytes: 10, modifiedAt: date),
            DuplicateFile(path: "/fixture/changed", bytes: 20), DuplicateFile(path: "/fixture/missing", bytes: 30)]))
        let text = try await service.document(for: before)
        let url = FileManager.default.temporaryDirectory.appending(path: "StorageFix-snapshot-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(text.utf8).write(to: url)
        let loaded = try await service.read(from: url)
        #expect(loaded.entries == before.entries)
        let current = try await service.capture(scan([DuplicateFile(path: "/fixture/same", bytes: 10, modifiedAt: date),
            DuplicateFile(path: "/fixture/changed", bytes: 25), DuplicateFile(path: "/fixture/new", bytes: 5)]))
        let result = try await service.compare(baseline: loaded, current: current)
        #expect(result.beforeBytes == 60 && result.afterBytes == 40 && result.observedByteChange == -20)
        #expect(result.unchangedCount == 1 && result.items.count == 3)
        #expect(result.items.map(\.change) == [.metadataChanged, .noLongerObserved, .newlyObserved])
        #expect(result.warnings.joined().contains("do not prove deletion"))
    }
    @Test func `Incomplete permissions cancellation and differing coverage remain explicit`() async throws {
        let service = ScanSnapshotService()
        var coverage = InventoryCoverage(); coverage.record(.init(path: "/fixture/secret", reason: .inaccessible))
        let baseline = try await service.capture(scan([DuplicateFile(path: "/fixture/a", bytes: 10)]))
        let current = try await service.capture(scan([], coverage: coverage, cancelled: true))
        let result = try await service.compare(baseline: baseline, current: current)
        #expect(current.hasIncompleteCoverage)
        #expect(result.items.first?.change == .noLongerObserved)
        #expect(result.warnings.contains { $0.contains("incomplete") })
        #expect(result.warnings.contains { $0.contains("counts changed") })
    }
    @Test func `Scope and inspection settings must match`() async throws {
        let service = ScanSnapshotService(), baseline = try await service.capture(scan([]))
        let different = try await service.capture(scan([], root: "/other"))
        await #expect(throws: ScanSnapshotError.differentScope) { try await service.compare(baseline: baseline, current: different) }
        var options = InventoryOptions(); options.includesHiddenFiles = true
        let hidden = try await service.capture(scan([], options: options))
        await #expect(throws: ScanSnapshotError.differentOptions) { try await service.compare(baseline: baseline, current: hidden) }
    }
    @Test(arguments: ["../escape", "/absolute", "folder//file", "folder/./file", "folder/../file", ""])
    func `Malformed relative paths cannot be imported`(path: String) async throws {
        let service = ScanSnapshotService(), good = try await service.capture(scan([DuplicateFile(path: "/fixture/a", bytes: 10)]))
        let text = try await service.document(for: good)
        var object = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        object["entries"] = [["relativePath": path, "logicalBytes": 10]]
        try await expectInvalid(object)
    }
    @Test func `Duplicate negative overflowing and future data are rejected`() async throws {
        let service = ScanSnapshotService(), good = try await service.capture(scan([]))
        let text = try await service.document(for: good)
        let object = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        for entries: [[String: Any]] in [
            [["relativePath": "a", "logicalBytes": -1]],
            [["relativePath": "a", "logicalBytes": 1], ["relativePath": "a", "logicalBytes": 2]],
            [["relativePath": "a", "logicalBytes": Int64.max], ["relativePath": "b", "logicalBytes": 1]]
        ] {
            var invalid = object; invalid["entries"] = entries
            try await expectInvalid(invalid)
        }
        var future = object; future["version"] = 2
        try await expectInvalid(future, error: .unsupportedVersion)
    }
    private func expectInvalid(_ object: [String: Any], error: ScanSnapshotError = .invalidDocument) async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "StorageFix-invalid-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        await #expect(throws: error) { try await ScanSnapshotService().read(from: url) }
    }
    @Test func `Cancellation never returns a completed snapshot`() async throws {
        let scan = scan([])
        let task = Task { try Task.checkCancellation(); return try await ScanSnapshotService().capture(scan) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
