import Foundation
import StorageFixCore
import Testing
@testable import WorkspaceFeature

/// A file service whose scan never returns until released, like a folder blocked on a macOS access prompt.
actor BlockedFileService: FileBrowserServiceProtocol {
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var started = false
    func scan(in root: URL) async throws -> [DuplicateFile] {
        started = true
        await withCheckedContinuation { waiter = $0 }   // ignores cancellation on purpose
        return []
    }
    func moveToTrash(paths: Set<String>) async throws {}
    func reveal(path: String) {}
    func release() { waiter?.resume(); waiter = nil }
}

@MainActor struct ReviewCancellationTests {
    @Test func `Caches are measured before folder files so the cleanup report is ready first`() async {
        let vm = fixtureWorkspace()
        await vm.review()
        #expect(vm.latestReport?.areas.first?.section == .cleanup)
    }

    @Test func `Cancelling returns immediately even while a folder scan is blocked`() async throws {
        let blocked = BlockedFileService()
        let vm = fixtureWorkspace(fileService: blocked)
        vm.startReview()
        while !(await blocked.started) { await Task.yield() }
        #expect(vm.isReviewing && vm.cleanup.hasScanned)
        vm.stopReview()
        for _ in 0..<200 where vm.isReviewing { await Task.yield() }
        #expect(!vm.isReviewing && vm.reviewMessage?.contains("cancelled") == true)
        await blocked.release()
    }

    @Test func `Review & Clean works mid-review once caches are measured`() async throws {
        let blocked = BlockedFileService()
        let vm = fixtureWorkspace(fileService: blocked)
        vm.startReview()
        while !(await blocked.started) { await Task.yield() }
        vm.reviewAndClean()
        for _ in 0..<200 where vm.selectedSection != .cleanup { await Task.yield() }
        #expect(vm.selectedSection == .cleanup && vm.cleanup.showsConfirmation)
        await blocked.release()
    }
}
