import Foundation
import StorageFixCore
@testable import StorageMapFeature
import Testing

@MainActor
struct StorageMapViewModelTests {
    private let root = URL(fileURLWithPath: "/fixture")

    @Test func `Given an injected inventory, when scanning and navigating, then chart and list totals stay equal without rescanning`() async throws {
        let service = MapInventoryFixture()
        let vm = StorageMapViewModel(root: root, service: service)
        await vm.scan()
        #expect(vm.hasScanned && vm.isLoading == false && vm.errorMessage == nil)
        #expect(vm.totalBytes == 3_750)
        #expect(vm.chartSlices.reduce(0) { $0 + $1.bytes } == vm.totalBytes)
        #expect(vm.chartSlices.last?.id == .remainder)
        let nested = try #require(vm.items.first { $0.isFolder })
        vm.enter(nested)
        #expect(vm.totalBytes == 150 && vm.chartSlices.count == 2)
        #expect(vm.chartSlices.reduce(0) { $0 + $1.bytes } == vm.totalBytes)
        vm.back()
        #expect(vm.totalBytes == 3_750 && vm.canGoBack == false)
        vm.enter(nested); vm.returnToRoot()
        #expect(vm.totalBytes == 3_750)
        #expect(await service.calls == 1)
    }

    @Test func `Given a scan error, when scanning, then stale map data clears and the reason is shown`() async {
        let vm = StorageMapViewModel(root: root, service: FailingMapInventory())
        vm.acceptInventory([DuplicateFile(path: "/fixture/old", bytes: 100)], root: root)
        await vm.scan()
        #expect(vm.hasScanned == false && vm.isLoading == false)
        #expect(vm.files.isEmpty && vm.items.isEmpty && vm.chartSlices.isEmpty && vm.totalBytes == 0)
        #expect(vm.errorMessage?.contains("Cannot read") == true)
    }

    @Test(arguments: [false, true])
    func `Given a pending scan, when completing or cancelling, then loading and result state reflect its lifetime`(cancel: Bool) async {
        let service = PausedMapInventory()
        let vm = StorageMapViewModel(root: root, service: service)
        let task = Task { await vm.scan() }
        await service.waitUntilStarted()
        #expect(vm.isLoading && vm.hasScanned == false)
        vm.chooseFolder(URL(fileURLWithPath: "/other"))
        #expect(vm.root == root)
        if cancel { task.cancel() }
        await service.finish()
        await task.value
        #expect(vm.isLoading == false)
        if cancel {
            #expect(vm.hasScanned == false && vm.items.isEmpty && vm.chartSlices.isEmpty)
            #expect(vm.errorMessage == nil && vm.resultMessage?.contains("cancelled") == true)
        } else {
            #expect(vm.hasScanned && vm.totalBytes == 100)
        }
    }

    @Test func `Given a Store folder requiring consent, when scanning, then the dependency is never called`() async {
        let service = MapInventoryFixture()
        let vm = StorageMapViewModel(root: root, service: service, requiresFolderSelection: true)
        await vm.scan()
        #expect(await service.calls == 0)
        #expect(vm.needsFolder && vm.hasScanned == false && vm.errorMessage != nil)
    }

    @Test func `Given shared scan results, when changing scope, then all cached projections and notices reset`() {
        let vm = StorageMapViewModel(root: root, service: MapInventoryFixture())
        vm.acceptInventory([DuplicateFile(path: "/fixture/a", bytes: 100),
                            DuplicateFile(path: "/outside/ignored", bytes: 1_000)], root: root)
        #expect(vm.totalBytes == 100 && vm.chartSlices.count == 1)
        #expect(vm.chartAccessibilityValue.contains(vm.shareDescription(100)))
        vm.chooseFolder(URL(fileURLWithPath: "/other"))
        #expect(vm.files.isEmpty && vm.items.isEmpty && vm.chartSlices.isEmpty && vm.totalBytes == 0)
        #expect(vm.hasScanned == false && vm.errorMessage == nil && vm.resultMessage == nil)
    }
}
