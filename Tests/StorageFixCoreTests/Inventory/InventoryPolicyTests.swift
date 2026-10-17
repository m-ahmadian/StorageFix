import Foundation
import StorageFixCore
import Testing

struct InventoryPolicyTests {
    @Test func `Array adapters exclude off-scope files and explicitly mark unavailable coverage`() async throws {
        let root = URL(fileURLWithPath: "/fixture")
        let result = try await ArrayInventory().inventory(in: root, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        #expect(result.files.map(\.path) == ["/fixture/file"])
        #expect(result.logicalBytes == 100 && !result.coverageAvailable)
        #expect(result.coverage.counts[.unsupported] == 1)
        #expect(InventorySummary(scan: result).title.contains("coverage unavailable"))
    }

    @Test(arguments: PolicyCase.allCases)
    func `Inspection, cancellation, shared links and read-only volumes cannot authorize Trash`(policy: PolicyCase) async throws {
        let root = URL(fileURLWithPath: "/fixture")
        let service = FileBrowserService(inventoryService: PolicyInventory(policy: policy), trash: { _ in Issue.record("Trash must not run") })
        var options = InventoryOptions()
        if policy == .inspection { options.includesHiddenFiles = true }
        _ = try await service.inventory(in: root, options: options, sessionID: UUID(), progress: { _ in })
        await #expect(throws: FileBrowserError.self) { try await service.moveToTrash(paths: ["/fixture/file"]) }
    }

    enum PolicyCase: CaseIterable, Sendable { case inspection, cancelled, sharedLink, readOnly }
}

private struct ArrayInventory: FileInventoryServiceProtocol {
    func scan(in root: URL) async throws -> [DuplicateFile] {
        [DuplicateFile(path: "/fixture/file", bytes: 100), DuplicateFile(path: "/outside/file", bytes: 999)]
    }
}

private struct PolicyInventory: FileInventoryServiceProtocol {
    let policy: InventoryPolicyTests.PolicyCase
    func scan(in root: URL) async throws -> [DuplicateFile] { [] }
    func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                   progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        InventoryScan(sessionID: sessionID, root: root, options: options,
            files: [DuplicateFile(path: "/fixture/file", bytes: 100, isSharedLink: policy == .sharedLink)],
            wasCancelled: policy == .cancelled,
            volume: InventoryVolume(name: nil, capacityBytes: nil, availableBytes: nil, isReadOnly: policy == .readOnly))
    }
}
