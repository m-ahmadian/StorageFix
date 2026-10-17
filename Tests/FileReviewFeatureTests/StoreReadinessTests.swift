import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import Foundation
import LargeFilesFeature
import StorageFixCore
import StorageMapFeature
import Testing
import WorkspaceFeature

@MainActor struct StoreReadinessTests {
    @Test func `Given the Store edition without a chosen folder, when reviewing, then no automatic scans run`() async {
        let vm = workspace(needsFolder: true)
        #expect(!vm.canReview && vm.supportsCleanup && vm.cleanup.needsAccess && vm.reviewStageCount == 2)
        #expect(vm.duplicates.scopeDescription == "Choose a folder to review")
        await vm.review()
        #expect(vm.completedSteps == 0 && !vm.files.hasScanned && !vm.apps.hasScanned)
        await vm.files.scan(); await vm.duplicates.scan(); await vm.map.scan(); await vm.apps.scan()
        #expect(vm.files.errorMessage != nil && vm.duplicates.errorMessage != nil && vm.map.errorMessage != nil && vm.apps.errorMessage != nil)
    }
    @Test func `Given an authorized folder but no Home grant, when reviewing, then caches and apps are not scanned`() async {
        let vm = workspace(needsFolder: false); await vm.review()
        #expect(vm.completedSteps == 2 && vm.files.hasScanned && vm.duplicates.hasScanned)
        #expect(!vm.cleanup.hasScanned && !vm.apps.hasScanned && vm.map.hasScanned)
    }
    @Test func `Given a read-only app inventory, when removal is requested, then the application remains`() async {
        let vm = ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false)
        await vm.scan(); vm.selectedApplication = vm.applications.first; await vm.moveToTrash()
        #expect(vm.applications.count == 1 && vm.resultMessage == nil)
    }
    @Test func `Given local activity, when clearing history, then both visible and persisted entries are removed`() async throws {
        let suite = "StorageFixHistory-\(UUID().uuidString)", defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = workspace(needsFolder: false, defaults: defaults); await vm.review()
        #expect(defaults.data(forKey: "storagefix.activity.v1") != nil)
        vm.clearActivity()
        #expect(vm.activity.isEmpty && defaults.data(forKey: "storagefix.activity.v1") == nil)
    }
    @Test func `Metadata-only review skips duplicate content comparison until explicitly enabled`() async throws {
        let vm = workspace(needsFolder: false)
        vm.setDuplicateComparison(false)
        #expect(vm.reviewStageCount == 1)
        await vm.review()
        #expect(vm.completedSteps == 1 && vm.files.hasScanned && !vm.duplicates.hasScanned)
        #expect(try #require(vm.latestReport).areas.map(\.section) == [.files])
    }

    @Test func `Given the Home grant in the Store edition, caches join the review and Review & Clean opens confirmation`() async {
        let vm = workspace(needsFolder: false, cleanup: FixtureCleanupService())
        #expect(vm.reviewsCaches && !vm.reviewsApplications && vm.reviewStageCount == 3)
        await vm.review()
        #expect(vm.cleanup.hasScanned && vm.cleanup.selectedBytes > 0 && !vm.apps.hasScanned)
        vm.reviewAndClean()
        #expect(vm.selectedSection == .cleanup && vm.cleanup.showsConfirmation)
    }
    private func workspace(needsFolder: Bool, defaults: UserDefaults? = nil, cleanup: (any CleanupServiceProtocol)? = nil) -> WorkspaceViewModel {
        let root = URL(fileURLWithPath: "/fixture")
        return WorkspaceViewModel(cleanup: CleanupViewModel(service: cleanup ?? StoreAccessCleanup()),
            duplicates: DuplicateViewModel(service: FixtureDuplicateService(), requiresFolderSelection: needsFolder),
            files: LargeFilesViewModel(scope: root, service: FixtureFileService(), requiresFolderSelection: needsFolder),
            map: StorageMapViewModel(root: root, service: FixtureFileService(), requiresFolderSelection: needsFolder),
            apps: ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false, requiresFolderSelection: true),
            defaults: defaults ?? UserDefaults(suiteName: "StorageFixStoreFixture-\(UUID().uuidString)")!, edition: .appStore, includesDuplicateComparison: true)
    }
}

/// Store-like cleanup that still needs the Home folder.
struct StoreAccessCleanup: CleanupServiceProtocol {
    var requiredFolder: URL? { URL(fileURLWithPath: "/Users/example") }
    var hasAccess: Bool { get async { false } }
    func scan() async throws -> CleanupReport { throw NativeCleanupError.accessRequired("/Users/example") }
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { try await scan() }
}
