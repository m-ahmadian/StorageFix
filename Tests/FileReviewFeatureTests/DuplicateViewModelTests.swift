import DuplicateFeature
import LargeFilesFeature
import Foundation
import StorageFixCore
import Testing

@MainActor
struct DuplicateViewModelTests {
    @Test func `Given matching files, when scanning, then copies require explicit selection`() async {
        let vm = DuplicateViewModel(service: ReviewService())
        await vm.scan()
        #expect(vm.groups.count == 1)
        #expect(vm.selectedPaths.isEmpty)
        #expect(vm.hasScanned)
    }
    @Test func `Given a kept original, when selecting it or an unknown path, then selection is ignored`() async {
        let vm = DuplicateViewModel(service: ReviewService()); await vm.scan()
        vm.setSelected(path: "/a", isSelected: true); vm.setSelected(path: "/unknown", isSelected: true)
        #expect(vm.selectedPaths.isEmpty)
        vm.setSelected(path: "/b", isSelected: true)
        #expect(vm.selectedBytes == 100)
    }
    @Test func `Given a selected copy, when keeping it instead, then the previous original is not silently selected`() async {
        let vm = DuplicateViewModel(service: ReviewService()); await vm.scan()
        vm.setSelected(path: "/b", isSelected: true); vm.keep(path: "/b", in: "group")
        #expect(vm.groups.first?.original.path == "/b")
        #expect(vm.selectedPaths.isEmpty)
    }
    @Test func `Given selected copies, when moving them to Trash, then the outcome is shown and stale results clear`() async {
        let service = ReviewService(); let vm = DuplicateViewModel(service: service)
        await vm.scan(); vm.toggleSelectAll(); await vm.remove()
        #expect(await service.removed == ["/b"])
        #expect(vm.selectedPaths.isEmpty && vm.groups.isEmpty)
        #expect(vm.resultMessage?.contains("Trash") == true)
        #expect(!vm.isLoading)
    }
    @Test func `A background scan started by the view model finishes on its own and can be cancelled`() async throws {
        let vm = DuplicateViewModel(service: ReviewService())
        vm.startScan()
        let deadline = Date().addingTimeInterval(30)
        while vm.isLoading || !vm.hasScanned, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(vm.hasScanned && vm.groups.count == 1 && vm.progress == nil && !vm.isScanning)
        vm.cancelScan()
        #expect(!vm.isLoading)
    }
    @Test func `Trash asks for confirmation first, even when the review queue exists`() async {
        let vm = DuplicateViewModel(service: ReviewService()); await vm.scan()
        vm.requestTrash()
        #expect(!vm.showsConfirmation)
        vm.setSelected(path: "/b", isSelected: true); vm.requestTrash()
        #expect(vm.showsConfirmation)
    }
    @Test func `Given a failed scan, when retrying successfully, then the previous error clears`() async {
        let service = ReviewService(failFirstScan: true); let vm = DuplicateViewModel(service: service)
        await vm.scan(); #expect(vm.errorMessage != nil)
        await vm.scan(); #expect(vm.errorMessage == nil); #expect(vm.hasScanned)
    }
    @Test func `Given a new folder, when choosing it, then previous results and selection clear`() async {
        let vm = DuplicateViewModel(service: ReviewService()); await vm.scan(); vm.toggleSelectAll()
        vm.chooseFolder(URL(fileURLWithPath: "/tmp"))
        #expect(vm.groups.isEmpty && vm.selectedPaths.isEmpty && !vm.hasScanned)
    }
    @Test func `Given no selection, when removing, then no service mutation occurs`() async {
        let service = ReviewService(); let vm = DuplicateViewModel(service: service)
        await vm.scan(); await vm.remove()
        #expect(await service.removed.isEmpty)
    }
    @Test func `Given a Downloads fixture, when scanning large files, then files are sorted by size`() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(repeating: 1, count: 100).write(to: folder.appending(path: "small"))
        try Data(repeating: 2, count: 200).write(to: folder.appending(path: "large"))
        let vm = LargeFilesViewModel(scope: folder, service: FileBrowserService()); await vm.scan()
        #expect(vm.files.map(\.bytes) == [200, 100]); #expect(vm.hasScanned && !vm.isLoading)
    }
}
private actor ReviewService: DuplicateServiceProtocol {
    var removed: Set<String> = []
    var failFirstScan: Bool
    init(failFirstScan: Bool = false) { self.failFirstScan = failFirstScan }
    func scan() async throws -> [DuplicateGroup] {
        if failFirstScan { failFirstScan = false; throw FileReviewError.unavailableFolder("fixture") }
        return [DuplicateGroup(id: "group", original: DuplicateFile(path: "/a", bytes: 100), duplicates: [DuplicateFile(path: "/b", bytes: 100)])]
    }
    func remove(paths: Set<String>) async throws { removed = paths }
    nonisolated func reveal(path: String) {}
}
