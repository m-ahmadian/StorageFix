import Foundation
import StorageFixCore
@testable import StorageMapFeature
import Testing

@MainActor struct StorageMapExplorationTests {
    private let root = URL(fileURLWithPath: "/fixture")

    @Test func `Chart and ranked list selection agree, including the remainder`() async throws {
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture())
        await vm.scan()
        vm.selectAngle(0)
        #expect(vm.selectedItem == vm.items.first)
        let last = try #require(vm.items.last)
        vm.selectItem(last)
        #expect(vm.selectedItem == last && vm.isSliceSelected(.remainder))
        vm.selectSlice(.remainder)
        #expect(vm.selectedItem == nil && vm.selectionTitle.contains("Other"))
        vm.selectAngle(.nan)
        #expect(vm.selectedID == nil)
        vm.selectSlice(.item("/outside/file"))
        #expect(vm.selectedID == nil)
    }

    @Test func `List filtering and sort preserve whole-folder chart proportions`() async throws {
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture())
        await vm.scan()
        let slices = vm.chartSlices
        vm.setQuery("item-1")
        #expect(vm.visibleItems.count == 1 && vm.chartSlices == slices && vm.totalBytes == 3750)
        vm.setQuery(""); vm.setSort(.smallest)
        #expect(vm.visibleItems.first?.bytes == 100)
        vm.setSort(.name)
        #expect(vm.visibleItems.first?.name == "item-1")
        vm.moveSelection(by: 1)
        #expect(vm.selectedItem == vm.visibleItems.first)
        vm.moveSelection(by: 1)
        #expect(vm.selectedItem == vm.visibleItems[1])
    }

    @Test func `Breadcrumbs navigate cached hierarchy and reject paths outside the active trail`() async throws {
        let service = MapInventoryFixture()
        let vm = StorageMapViewModel(root: root, service: service)
        await vm.scan()
        let folder = try #require(vm.items.first { $0.isFolder })
        vm.selectItem(folder); vm.exploreSelection()
        #expect(vm.current.path == "/fixture/nested" && vm.breadcrumbs.count == 2 && vm.selectedID == nil)
        let rootCrumb = try #require(vm.breadcrumbs.first)
        vm.navigate(to: MapBreadcrumb(path: "/outside", name: "Outside"))
        #expect(vm.current.path == "/fixture/nested")
        vm.navigate(to: rootCrumb)
        #expect(vm.current == root && vm.totalBytes == 3750)
        #expect(await service.calls == 1)
    }

    @Test func `Quick Look and Finder route selected inventory through the injected coordinator`() async throws {
        let presenter = RecordingFilePresenter()
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture(), presenter: presenter)
        await vm.scan()
        let file = try #require(vm.items.first { !$0.isFolder })
        vm.selectItem(file); vm.previewSelection(); vm.revealSelection()
        #expect(presenter.previews.map(\.path) == [file.path])
        #expect(presenter.reveals.map(\.path) == [file.path])
        let folder = try #require(vm.items.first { $0.isFolder })
        vm.selectItem(folder); vm.previewSelection()
        #expect(!vm.canPreview && presenter.previews.count == 1)
        vm.chooseFolder(URL(fileURLWithPath: "/new"))
        vm.previewSelection(); vm.revealSelection()
        #expect(presenter.previews.count == 1 && presenter.reveals.count == 1)
    }
}

@MainActor private final class RecordingFilePresenter: FilePresentationCoordinating {
    private(set) var previews: [URL] = []
    private(set) var reveals: [URL] = []
    func preview(_ url: URL) { previews.append(url) }
    func reveal(_ url: URL) { reveals.append(url) }
}
