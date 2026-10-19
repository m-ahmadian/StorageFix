import Foundation
import SimilarPhotosFeature
import StorageFixCore
import Testing
import WorkspaceFeature

@MainActor struct SimilarPhotosViewModelTests {
    actor FakePhotos: SimilarPhotoServiceProtocol {
        var trashed: [String] = []
        let failing: Set<String>
        init(failing: Set<String> = []) { self.failing = failing }
        func scan(in root: URL, progress: @escaping @Sendable (SimilarPhotoProgress) -> Void) async throws -> SimilarPhotoScan {
            progress(SimilarPhotoProgress(analyzed: 5, total: 5))
            let a = [photo("/p/a1.jpg", 4000), photo("/p/a2.jpg", 1000), photo("/p/a3.jpg", 900)]
            let b = [photo("/p/b1.jpg", 3000), photo("/p/b2.jpg", 2000)]
            return SimilarPhotoScan(groups: [SimilarPhotoGroup(photos: a), SimilarPhotoGroup(photos: b)], analyzedCount: 5, wasLimited: false)
        }
        func moveToTrash(_ photos: [SimilarPhoto]) async -> [String] {
            trashed += photos.map(\.path)
            return photos.map(\.path).filter(failing.contains)
        }
        nonisolated func photo(_ path: String, _ pixels: Int) -> SimilarPhoto {
            SimilarPhoto(path: path, bytes: Int64(pixels), modifiedAt: nil, pixelWidth: pixels, pixelHeight: 1)
        }
    }

    @Test func `Scanning selects nothing and a group can never lose its last photo`() async {
        let vm = SimilarPhotosViewModel(service: FakePhotos(), folder: URL(fileURLWithPath: "/p"))
        await vm.scan()
        #expect(vm.groups.count == 2 && vm.selectedPaths.isEmpty && vm.extraBytes == 1900 + 2000)
        vm.setSelected("/p/b1.jpg", true)
        vm.setSelected("/p/b2.jpg", true)
        #expect(vm.selectedPaths == ["/p/b1.jpg"])
    }

    @Test func `Select all but best leaves every suggested photo, and Trash removes only what moved`() async {
        let service = FakePhotos(failing: ["/p/a3.jpg"])
        let vm = SimilarPhotosViewModel(service: service, folder: URL(fileURLWithPath: "/p"))
        await vm.scan()
        vm.selectAllButBest()
        #expect(vm.selectedPaths == ["/p/a2.jpg", "/p/a3.jpg", "/p/b2.jpg"])
        vm.requestTrash()
        #expect(vm.showsConfirmation)
        await vm.confirmTrash()
        #expect(await service.trashed.sorted() == ["/p/a2.jpg", "/p/a3.jpg", "/p/b2.jpg"])
        #expect(vm.groups.map { $0.photos.map(\.path) } == [["/p/a1.jpg", "/p/a3.jpg"]])
        #expect(vm.resultMessage?.contains("Moved 2 photos") == true && vm.errorMessage != nil && vm.selectedPaths.isEmpty)
    }

    @Test func `Without a folder nothing is scanned, and a default folder never replaces a chosen one`() async {
        let vm = SimilarPhotosViewModel(service: FakePhotos())
        await vm.scan()
        #expect(!vm.hasScanned && vm.errorMessage != nil)
        vm.chooseFolder(URL(fileURLWithPath: "/mine"))
        vm.offerDefaultFolder(URL(fileURLWithPath: "/Users/x/Pictures"))
        #expect(vm.folder?.path == "/mine")
    }

    @Test func `The menu bar shows free space and warns when the disk is nearly full`() {
        let roomy = FreeSpaceMonitor(read: { (200_000_000_000, 500_000_000_000) }, refreshInterval: nil)
        #expect(!roomy.isLow && abs(roomy.usedFraction - 0.6) < 0.001 && roomy.title.contains("GB"))
        let tight = FreeSpaceMonitor(read: { (30_000_000_000, 500_000_000_000) }, refreshInterval: nil)
        #expect(tight.isLow)
        let tiny = FreeSpaceMonitor(read: { (10_000_000_000, 64_000_000_000) }, refreshInterval: nil)
        #expect(tiny.isLow)
        let unknown = FreeSpaceMonitor(read: { (nil, nil) }, refreshInterval: nil)
        #expect(unknown.title == "—" && !unknown.isLow)
    }
}
