import Foundation
import LargeFilesFeature
import DuplicateFeature
import ReviewQueueFeature
import StorageFixCore
import StorageMapFeature
import Testing

@MainActor struct ReviewQueueViewModelTests {
    @Test func `Success presents exact confirmation and consumes completed queue results`() async throws {
        let queue = featureQueue()
        addFile(to: queue)
        let vm = ReviewQueueViewModel(queue: queue)
        #expect(vm.canExecute && vm.logicalBytes == 100_000_000)
        vm.requestConfirmation()
        #expect(vm.showsConfirmation && vm.confirmationSnapshot?.items.count == 1)
        await vm.execute()
        #expect(!vm.isExecuting && !vm.showsConfirmation && vm.snapshot.items.isEmpty)
        #expect(vm.snapshot.lastRun?.movedCount == 1)
    }

    @Test func `Validation failure shows blocked outcomes and prevents an unchanged retry`() async {
        let queue = featureQueue(operations: QueueFeatureOperations(fail: true))
        addFile(to: queue)
        let vm = ReviewQueueViewModel(queue: queue)
        vm.requestConfirmation(); await vm.execute()
        #expect(vm.snapshot.lastRun?.outcomes.first?.status == .blocked)
        #expect(!vm.canExecute && vm.snapshot.items.count == 1)
    }

    @Test func `Loading follows the queue operation and confirmed paths stay frozen`() async throws {
        let ops = QueueFeatureOperations(pause: true)
        let queue = featureQueue(operations: ops)
        addFile(to: queue)
        let vm = ReviewQueueViewModel(queue: queue)
        vm.requestConfirmation()
        let task = Task { await vm.execute() }
        await ops.waitUntilStarted()
        #expect(vm.isExecuting && !vm.canExecute)
        vm.clear()
        #expect(vm.snapshot.items.count == 1)
        await ops.finish(); await task.value
        #expect(!vm.isExecuting && vm.snapshot.lastRun?.movedCount == 1)
    }

    @Test func `A changed queue dismisses stale confirmation without moving files`() async {
        let ops = QueueFeatureOperations()
        let queue = featureQueue(operations: ops)
        addFile(to: queue)
        let vm = ReviewQueueViewModel(queue: queue)
        vm.requestConfirmation()
        queue.clear()
        #expect(!vm.showsConfirmation && vm.confirmationSnapshot == nil && vm.message != nil)
        await vm.execute()
        #expect(await ops.moves.isEmpty)
    }

    @Test func `Map, files and duplicates share one queue and clear stale scans after mutation`() async throws {
        let queue = featureQueue(), service = QueueFeatureFiles()
        let map = StorageMapViewModel(root: service.root, service: service, queue: queue)
        let files = LargeFilesViewModel(scope: service.root, service: service, queue: queue)
        let duplicates = DuplicateViewModel(service: service, scopeDescription: service.root.path, queue: queue)
        await map.scan(); await files.scan(); await duplicates.scan()
        let kept = try #require(map.items.first { $0.path == "/fixture/a" })
        map.selectItem(kept); map.addSelectionToQueue()
        #expect(queue.snapshot.items.isEmpty && map.queueAddResult?.rejections.count == 1)
        files.setSelected("/fixture/b", selected: true); files.reviewSelected()
        duplicates.setSelected(path: "/fixture/b", isSelected: true); duplicates.reviewSelected()
        #expect(queue.snapshot.items.count == 1 && queue.snapshot.items.first?.origins == [.files, .duplicates])
        let vm = ReviewQueueViewModel(queue: queue)
        vm.requestConfirmation(); await vm.execute()
        #expect(vm.snapshot.lastRun?.movedCount == 1)
        #expect(!map.hasScanned && !files.hasScanned && !duplicates.hasScanned)
    }

    private func addFile(to queue: ReviewQueue) {
        let fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
    }
}
