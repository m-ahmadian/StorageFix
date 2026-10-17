import Foundation
@testable import ReviewQueueFeature
import StorageFixCore
import Testing
@testable import WorkspaceFeature

struct FixedVolume: VolumeInformationServiceProtocol {
    let capacity: Int64
    let available: Int64
    func volume(at root: URL) -> InventoryVolume? {
        InventoryVolume(name: "Fixture", capacityBytes: capacity, availableBytes: available, isReadOnly: false)
    }
}

@MainActor struct WorkspacePolishTests {
    @Test(arguments: [(500, StoragePressure.comfortable), (140, .tight), (30, .critical)])
    func `The capacity ring reports used share and pressure from free space`(available: Int64, expected: StoragePressure) {
        let vm = fixtureWorkspace(volumeService: FixedVolume(capacity: 1_000, available: available))
        vm.refreshDisk()
        #expect(vm.storagePressure == expected)
        #expect(abs((vm.usedFraction ?? -1) - (1 - Double(available) / 1_000)) < 0.0001)
    }

    @Test func `Unknown capacity gives no pressure and no status`() {
        let vm = fixtureWorkspace()
        #expect(vm.usedFraction == nil && vm.storagePressure == .unknown && vm.storagePressure.status == nil)
        #expect(StoragePressure(usedFraction: 0.849) == .comfortable && StoragePressure(usedFraction: 0.85) == .tight)
        #expect(StoragePressure(usedFraction: 0.95) == .critical)
    }

    @Test func `The queue pill appears only on inspection screens while files are queued`() async {
        let queue = featureQueue()
        let queueVM = ReviewQueueViewModel(queue: queue)
        let vm = fixtureWorkspace(queue: queueVM)
        await vm.review(); vm.select(.map)
        #expect(vm.queuePillSummary == nil)
        let fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        #expect(vm.queuePillSummary?.hasPrefix("1 file") == true)
        vm.select(.queue)
        #expect(vm.queuePillSummary == nil)
        vm.select(.overview)
        #expect(vm.queuePillSummary == nil)
    }

    @Test func `A tiny free-space change after a large move explains Trash and snapshots`() async {
        let volumes = SequencedFeatureVolumes(available: [1_000, 1_100])
        let queue = ReviewQueue(policy: ReviewFilePolicy(protectedRoots: []), operations: QueueFeatureOperations(), volumes: volumes)
        let vm = ReviewQueueViewModel(queue: queue)
        let fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        vm.requestConfirmation(); await vm.execute()
        #expect(vm.freeSpaceLooksUnchanged(change: 100))
        #expect(!vm.freeSpaceLooksUnchanged(change: 50_000_000))
        #expect(vm.freeSpaceDescription?.contains("local snapshots") == true)
    }
}
