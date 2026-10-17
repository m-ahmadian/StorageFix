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
    @Test func `Prepared indexes follow fresh inventory and clear with scope changes`() throws {
        let root = URL(fileURLWithPath: "/fixture"), files = [DuplicateFile(path: "/fixture/nested/a", bytes: 10)]
        let index = try StorageMapIndex(files: files, root: root)
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture())
        vm.acceptInventory(InventoryScan(sessionID: UUID(), root: root, options: InventoryOptions(), files: files, mapIndex: index))
        if let folder = vm.items.first { vm.enter(folder) }
        #expect(vm.items.first?.path == "/fixture/nested/a")
        vm.acceptInventory([], root: root)
        #expect(vm.items.isEmpty && vm.totalBytes == 0)
    }

}
