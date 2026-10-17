import Foundation
import StorageFixCore
import StorageMapFeature
import Testing

@MainActor struct MapProjectionCacheTests {
    @Test func `Revisited folders remain consistent and replacement inventories invalidate cached projections`() {
        let root = URL(fileURLWithPath: "/fixture")
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture())
        vm.acceptInventory([DuplicateFile(path: "/fixture/nested/a", bytes: 10)], root: root)
        if let folder = vm.items.first { vm.enter(folder) }
        #expect(vm.totalBytes == 10 && vm.items.first?.path == "/fixture/nested/a")
        vm.back()
        if let folder = vm.items.first { vm.enter(folder) }
        #expect(vm.totalBytes == 10)
        vm.acceptInventory([DuplicateFile(path: "/fixture/nested/b", bytes: 20)], root: root)
        if let folder = vm.items.first { vm.enter(folder) }
        #expect(vm.totalBytes == 20 && vm.items.first?.path == "/fixture/nested/b")
        vm.chooseFolder(URL(fileURLWithPath: "/other"))
        #expect(vm.items.isEmpty && vm.totalBytes == 0)
    }
}
