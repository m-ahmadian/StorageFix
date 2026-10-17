import Foundation
@testable import ReviewQueueFeature
import StorageFixCore
import Testing

@MainActor struct FreeSpaceViewModelTests {
    @Test func `Queue view model offers remeasurement only after a measured operation`() async {
        let volumes = SequencedFeatureVolumes(available: [1_000, 1_100])
        let queue = ReviewQueue(policy: ReviewFilePolicy(protectedRoots: []), operations: QueueFeatureOperations(), volumes: volumes)
        let vm = ReviewQueueViewModel(queue: queue)
        #expect(!vm.canRemeasureFreeSpace && vm.freeSpaceDescription == nil)
        let fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        vm.requestConfirmation(); await vm.execute()
        #expect(vm.canRemeasureFreeSpace)
        #expect(vm.freeSpaceDescription?.contains("increased") == true && vm.freeSpaceDescription?.contains("empty Trash") == true)
        vm.remeasureFreeSpace()
        #expect(vm.snapshot.lastRun?.freeSpace?.afterBytes == 1_100)
    }
}

final class SequencedFeatureVolumes: VolumeInformationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var available: [Int64?]
    init(available: [Int64?]) { self.available = available }
    func volume(at root: URL) -> InventoryVolume? {
        lock.lock(); defer { lock.unlock() }
        let value = available.count > 1 ? available.removeFirst() : available.first ?? nil
        return InventoryVolume(name: "Fixture", capacityBytes: 10_000, availableBytes: value, isReadOnly: false)
    }
}
