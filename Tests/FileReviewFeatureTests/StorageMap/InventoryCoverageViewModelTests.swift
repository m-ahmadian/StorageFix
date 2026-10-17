import Foundation
import LargeFilesFeature
import StorageFixCore
@testable import StorageMapFeature
import Testing

@MainActor struct InventoryCoverageViewModelTests {
    private let root = URL(fileURLWithPath: "/fixture")

    @Test func `Rich metadata success publishes coverage, read-only volume and allocated unknowns`() async throws {
        let vm = StorageMapViewModel(root: root, service: RichInventoryFixture(readOnly: true))
        await vm.scan()
        let result = try #require(vm.inventoryResult)
        #expect(vm.hasScanned && vm.totalBytes == 120)
        #expect(result.knownAllocatedBytes == 64 && result.unknownAllocatedCount == 1)
        #expect(vm.coverageSummary?.title.contains("Partial") == true)
        #expect(vm.coverageSummary?.volumeDetail.contains("Read-only") == true)
        vm.chooseFolder(URL(fileURLWithPath: "/new"))
        #expect(vm.inventoryResult == nil && vm.progress == nil)
    }

    @Test func `A cancelled partial inventory remains inspectable but cannot authorize file selection`() async {
        let service = RichInventoryFixture(cancelled: true)
        let map = StorageMapViewModel(root: root, service: service)
        await map.scan()
        #expect(map.hasScanned && map.totalBytes == 120)
        #expect(map.resultMessage?.contains("Partial") == true)
        let files = LargeFilesViewModel(scope: root, service: service)
        await files.scan()
        files.setSelected("/fixture/a", selected: true)
        #expect(files.hasScanned && files.files.count == 2 && files.selectedPaths.isEmpty)
        #expect(files.resultMessage?.contains("Partial") == true)
    }

    @Test func `Hard links remain visible but cannot be selected for removal`() async {
        let vm = LargeFilesViewModel(scope: root, service: RichInventoryFixture())
        await vm.scan()
        vm.setSelected("/fixture/b", selected: true)
        #expect(vm.selectedPaths.isEmpty)
        vm.setSelected("/fixture/a", selected: true)
        #expect(vm.selectedPaths == ["/fixture/a"])
    }

    @Test func `Read-only volume inventory remains inspectable without removal selection`() async {
        let vm = LargeFilesViewModel(scope: root, service: RichInventoryFixture(readOnly: true))
        await vm.scan()
        vm.setSelected("/fixture/a", selected: true)
        #expect(!vm.canSelectFiles && vm.selectedPaths.isEmpty && vm.files.count == 2)
    }

    @Test func `Progress is monotonic and cannot cross a session boundary`() async throws {
        let service = PausedRichInventory()
        let vm = StorageMapViewModel(root: root, service: service)
        let task = Task { await vm.scan() }
        let session = await service.waitUntilStarted()
        #expect(vm.isLoading)
        vm.acceptInventory(InventoryScan(sessionID: UUID(), root: URL(fileURLWithPath: "/old"),
            options: InventoryOptions(), files: [DuplicateFile(path: "/old/file", bytes: 999)]))
        #expect(vm.inventoryResult == nil && vm.root == root && vm.files.isEmpty)
        vm.receiveProgress(InventoryProgress(sessionID: session, visitedCount: 10, fileCount: 2))
        vm.receiveProgress(InventoryProgress(sessionID: session, visitedCount: 2, fileCount: 1))
        vm.receiveProgress(InventoryProgress(sessionID: UUID(), visitedCount: 999, fileCount: 999))
        #expect(vm.progress?.visitedCount == 10)
        await service.finish()
        await task.value
        vm.chooseFolder(URL(fileURLWithPath: "/other"))
        vm.receiveProgress(InventoryProgress(sessionID: session, visitedCount: 100, fileCount: 10))
        #expect(vm.progress == nil && vm.inventoryResult == nil)
    }
}

struct RichInventoryFixture: FileBrowserServiceProtocol {
    var cancelled = false
    var readOnly = false
    func scan(in root: URL) async throws -> [DuplicateFile] { throw FileReviewError.unreviewedFile }
    func moveToTrash(paths: Set<String>) async throws { Issue.record("Unexpected removal") }
    func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                   progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        var coverage = InventoryCoverage()
        coverage.record(InventoryIssue(path: "/fixture/locked", reason: .inaccessible))
        return InventoryScan(sessionID: sessionID, root: root, options: options,
            files: [DuplicateFile(path: "/fixture/a", bytes: 100, allocatedBytes: 64),
                    DuplicateFile(path: "/fixture/b", bytes: 20, isSharedLink: true)],
            coverage: coverage, wasCancelled: cancelled,
            volume: InventoryVolume(name: "External fixture", capacityBytes: 1000, availableBytes: 500, isReadOnly: readOnly))
    }
}

private actor PausedRichInventory: FileInventoryServiceProtocol {
    private var session: UUID?
    private var observer: CheckedContinuation<UUID, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func scan(in root: URL) async throws -> [DuplicateFile] { [] }
    func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                   progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        session = sessionID; observer?.resume(returning: sessionID); observer = nil
        await withCheckedContinuation { waiter = $0 }
        return InventoryScan(sessionID: sessionID, root: root, options: options, files: [])
    }
    func waitUntilStarted() async -> UUID {
        if let session { return session }
        return await withCheckedContinuation { observer = $0 }
    }
    func finish() { waiter?.resume(); waiter = nil }
}
