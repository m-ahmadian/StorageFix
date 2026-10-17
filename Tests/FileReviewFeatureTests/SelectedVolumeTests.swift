import Foundation
import StorageFixCore
import Testing

@MainActor struct SelectedVolumeTests {
    @Test func `Disk overview follows the chosen review scope rather than the home volume`() {
        let vm = fixtureWorkspace(volumeService: FixtureVolumeService())
        vm.refreshDisk()
        #expect(vm.capacityBytes == 100 && vm.availableBytes == 10)
        vm.chooseReviewFolder(URL(fileURLWithPath: "/external"))
        #expect(vm.capacityBytes == 200 && vm.availableBytes == 20)
        vm.chooseReviewFolder(URL(fileURLWithPath: "/unavailable"))
        #expect(vm.capacityBytes == nil && vm.availableBytes == nil)
    }
}

private struct FixtureVolumeService: VolumeInformationServiceProtocol {
    func volume(at root: URL) -> InventoryVolume? {
        guard root.path != "/unavailable" else { return nil }
        let external = root.path == "/external"
        return InventoryVolume(name: nil, capacityBytes: external ? 200 : 100,
            availableBytes: external ? 20 : 10, isReadOnly: external)
    }
}
