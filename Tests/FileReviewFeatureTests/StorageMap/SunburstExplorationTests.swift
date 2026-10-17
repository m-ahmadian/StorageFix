import Foundation
import StorageFixCore
@testable import StorageMapFeature
import Testing

@MainActor struct SunburstExplorationTests {
    @Test func `Outer segments open their parent and select the correct cached child`() async throws {
        let service = SunburstInventoryFixture()
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: service)
        await vm.scan(); vm.setMapStyle(.sunburst)
        let child = try #require(vm.sunburstSegments.first { $0.isOuter && $0.slice.name == "Sub" })
        vm.activateSunburst(child)
        #expect(vm.current.path == "/fixture/Video" && vm.selectedItem?.name == "Sub")
        vm.exploreSelection()
        #expect(vm.current.path == "/fixture/Video/Sub" && vm.items.first?.name == "b.mov")
        vm.returnToRoot(); vm.setMapStyle(.treemap)
        #expect(vm.sunburstSegments.isEmpty && vm.current.path == "/fixture")
        #expect(await service.calls == 1)
    }
}

actor SunburstInventoryFixture: FileInventoryServiceProtocol {
    private(set) var calls = 0
    func scan(in root: URL) async throws -> [DuplicateFile] {
        calls += 1
        return [DuplicateFile(path: "/fixture/Video/a.mov", bytes: 30_000_000),
                DuplicateFile(path: "/fixture/Video/Sub/b.mov", bytes: 10_000_000),
                DuplicateFile(path: "/fixture/Photos/p.jpg", bytes: 20_000_000),
                DuplicateFile(path: "/fixture/notes.txt", bytes: 10_000_000)]
    }
}
