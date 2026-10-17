import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import Foundation
import LargeFilesFeature
import ReviewQueueFeature
import ScanComparisonFeature
import StorageFixCore
import StorageMapFeature
import Testing
import WorkspaceFeature

@MainActor
struct WorkspaceJourneyTests {
    @Test func `Given files of mixed kind and age, when filtering, then only matching modified files are shown`() async {
        let vm = LargeFilesViewModel(scope: URL(fileURLWithPath: "/fixture"), service: FixtureFileService())
        await vm.scan(); vm.minimumMB = 10; vm.kind = .images; vm.age = .year
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(vm.filteredFiles(now: now).map(\.path) == ["/fixture/old.jpg"])
        vm.query = "absent"; #expect(vm.filteredFiles(now: now).isEmpty)
    }
    @Test func `Given a selected file hidden by filters, when filtering changes, then selection remains explicit until cleared`() async {
        let vm = LargeFilesViewModel(scope: URL(fileURLWithPath: "/fixture"), service: FixtureFileService())
        await vm.scan(); vm.setSelected("/fixture/old.jpg", selected: true); vm.query = "new"
        #expect(vm.selectedPaths == ["/fixture/old.jpg"]); #expect(vm.selectedBytes == 20_000_000)
        vm.clearSelection(); #expect(vm.selectedPaths.isEmpty)
    }
    @Test func `Given a reviewed file selection, when Trash succeeds, then stale results clear and the result is shown`() async {
        let vm = LargeFilesViewModel(scope: URL(fileURLWithPath: "/fixture"), service: FixtureFileService())
        await vm.scan(); vm.setSelected("/fixture/old.jpg", selected: true); await vm.moveToTrash()
        #expect(vm.files.isEmpty && vm.selectedPaths.isEmpty && !vm.hasScanned)
        #expect(vm.resultMessage?.hasPrefix("Moved") == true)
    }
    @Test func `Given a folder map, when exploring and going back, then the scanned inventory is reused`() {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: FixtureFileService())
        vm.acceptInventory([DuplicateFile(path: "/fixture/nested/a", bytes: 50)], root: vm.root)
        let item = vm.items[0]; vm.enter(item)
        #expect(vm.canGoBack && vm.items.first?.name == "a")
        vm.back(); #expect(!vm.canGoBack && vm.totalBytes == 50)
        vm.enter(StorageMapItemFixture.invalid); #expect(!vm.canGoBack)
    }
    @Test func `Given a quick review, when scans complete, then each area is ready and the map reuses file results`() async {
        let vm = fixtureWorkspace(); await vm.review()
        #expect(vm.completedSteps == 4 && vm.lastReviewDate != nil && !vm.isReviewing)
        #expect(vm.cleanup.hasScanned && vm.files.hasScanned && vm.duplicates.hasScanned && vm.apps.hasScanned)
        #expect(vm.map.files == vm.files.files)
        #expect(vm.activity.first?.title == "Quick review")
        #expect(vm.reviewMessage?.contains("ready") == true)
    }
    @Test func `Given one scan failure, when quick review runs, then other areas still complete and the error is reported`() async {
        let vm = fixtureWorkspace(failApps: true); await vm.review()
        #expect(vm.completedSteps == 4 && vm.files.hasScanned)
        #expect(vm.apps.errorMessage != nil && vm.reviewMessage?.contains("attention") == true)
    }
    @Test func `Given selected copies, when reviewing removal, then full selected paths are available independently of list filters`() async {
        let vm = DuplicateViewModel(service: FixtureDuplicateService()); await vm.scan()
        vm.setSelected(path: "/fixture/b.pdf", isSelected: true)
        #expect(vm.selectedFiles.map(\.path) == ["/fixture/b.pdf"])
        vm.keep(path: "/fixture/b.pdf", in: "fixture")
        #expect(vm.selectedFiles.isEmpty)
    }
    @Test func `Given an installed app, when its removal fails, then its row remains for review`() async {
        let vm = ApplicationsViewModel(service: FixtureApplicationService(failRemoval: true))
        await vm.scan(); vm.selectedApplication = vm.applications.first; await vm.moveToTrash()
        #expect(vm.applications.count == 1 && vm.errorMessage != nil && !vm.isLoading && !vm.isRemoving)
    }
    @Test func `Given a completed review, when choosing another scope, then previous folder results and review status clear`() async {
        let vm = fixtureWorkspace(); await vm.review(); vm.chooseReviewFolder(URL(fileURLWithPath: "/new"))
        #expect(vm.files.files.isEmpty && vm.duplicates.groups.isEmpty && vm.map.files.isEmpty)
        #expect(vm.lastReviewDate == nil && vm.files.scope.path == "/new")
    }
}
@MainActor
func fixtureWorkspace(failApps: Bool = false, volumeService: (any VolumeInformationServiceProtocol)? = nil, queue: ReviewQueueViewModel? = nil, comparison: ScanComparisonViewModel? = nil) -> WorkspaceViewModel {
    let defaults = UserDefaults(suiteName: "StorageFixFixture-\(UUID().uuidString)")!
    return WorkspaceViewModel(cleanup: CleanupViewModel(service: FixtureCleanupService()),
        duplicates: DuplicateViewModel(service: FixtureDuplicateService(), scopeDescription: "/fixture"),
        files: LargeFilesViewModel(scope: URL(fileURLWithPath: "/fixture"), service: FixtureFileService()),
        map: StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: FixtureFileService()), apps: ApplicationsViewModel(service: FixtureApplicationService(failScan: failApps)), defaults: defaults, edition: .direct, includesDuplicateComparison: true, volumeService: volumeService, reviewQueue: queue, scanComparison: comparison)
}
struct FixtureCleanupService: CleanupServiceProtocol {
    func scan() async throws -> CleanupReport {
        CleanupReport(mode: "scan", freeBytesBefore: 100_000_000_000, freeBytesAfter: 100_000_000_000, freeBytesReclaimed: 0,
            categories: [CleanupCategory(id: "xcode-derived-data", name: "Xcode Derived Data", path: "~/Library/Developer/Xcode/DerivedData", safeDefault: true, warning: "", bytesBefore: 3_400_000_000, bytesAfter: 3_400_000_000)])
    }
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { try await scan() }
}
struct FixtureDuplicateService: DuplicateServiceProtocol {
    func scan() async throws -> [DuplicateGroup] { [DuplicateGroup(id: "fixture", original: DuplicateFile(path: "/fixture/a.pdf", bytes: 12_000_000), duplicates: [DuplicateFile(path: "/fixture/b.pdf", bytes: 12_000_000)])] }
    func remove(paths: Set<String>) async throws {}
    func reveal(path: String) {}
}
struct FixtureFileService: FileBrowserServiceProtocol {
    func scan(in root: URL) async throws -> [DuplicateFile] {
        [DuplicateFile(path: "/fixture/old.jpg", bytes: 20_000_000, modifiedAt: Date(timeIntervalSince1970: 1_000_000_000)),
         DuplicateFile(path: "/fixture/new.pdf", bytes: 120_000_000, modifiedAt: Date(timeIntervalSince1970: 1_790_000_000)),
         DuplicateFile(path: "/fixture/unknown.jpg", bytes: 20_000_000)]
    }
    func moveToTrash(paths: Set<String>) async throws {}
}
struct FixtureApplicationService: ApplicationServiceProtocol {
    var failScan = false
    var failRemoval = false
    func scan() async throws -> [InstalledApplication] {
        if failScan { throw ApplicationReviewError.unreviewed }
        return [InstalledApplication(path: "/Applications/Example.app", name: "Example", bundleIdentifier: "com.storagefix.example", version: "1.0", bytes: 120_000_000)]
    }
    func moveToTrash(_ app: InstalledApplication) async throws { if failRemoval { throw ApplicationReviewError.running } }
}
private enum StorageMapItemFixture {
    static var invalid: StorageMapItem { StorageMap.items(files: [DuplicateFile(path: "/other/folder/file", bytes: 1)], at: URL(fileURLWithPath: "/other"))[0] }
}
