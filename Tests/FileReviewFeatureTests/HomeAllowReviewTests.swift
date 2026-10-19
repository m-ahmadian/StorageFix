import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import Foundation
import LargeFilesFeature
import StorageFixCore
import StorageMapFeature
import Testing
import WorkspaceFeature

/// The sandboxed first run: one Allow click on Home, then the review runs with no folder to pick.
@MainActor struct HomeAllowReviewTests {
    @Test func `Allowing Home picks Downloads and starts the review with caches first`() async throws {
        let home = URL(fileURLWithPath: "/Users/example")
        let vm = workspace(autoFolder: home.appending(path: "Downloads"))
        #expect(vm.needsHomeAllow && !vm.canReview)
        #expect(await vm.allowHomeAndReview(home))
        #expect(!vm.needsHomeAllow && vm.files.scope.path == "/Users/example/Downloads")
        let deadline = Date().addingTimeInterval(10)
        while vm.latestReport == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.latestReport?.areas.first?.section == .cleanup)
    }

    @Test func `Choosing another folder does not grant access or start anything`() async {
        let vm = workspace(autoFolder: URL(fileURLWithPath: "/Users/example/Downloads"))
        #expect(await vm.allowHomeAndReview(URL(fileURLWithPath: "/tmp")) == false)
        #expect(vm.needsHomeAllow && !vm.isReviewing && vm.reviewMessage?.contains("Home") == true)
    }

    private func workspace(autoFolder: URL) -> WorkspaceViewModel {
        let root = URL(fileURLWithPath: "/fixture")
        return WorkspaceViewModel(cleanup: CleanupViewModel(service: GrantingCleanup()),
            duplicates: DuplicateViewModel(service: FixtureDuplicateService(), requiresFolderSelection: true),
            files: LargeFilesViewModel(scope: root, service: FixtureFileService(), requiresFolderSelection: true),
            map: StorageMapViewModel(root: root, service: FixtureFileService(), requiresFolderSelection: true),
            apps: ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false, requiresFolderSelection: true),
            defaults: UserDefaults(suiteName: "StorageFixAllow-\(UUID().uuidString)")!, edition: .appStore, autoReviewFolder: autoFolder)
    }
}

/// Store-like cleanup that accepts only /Users/example, then scans like the fixture.
private actor GrantingCleanup: CleanupServiceProtocol {
    nonisolated var requiredFolder: URL? { URL(fileURLWithPath: "/Users/example") }
    private var granted = false
    var hasAccess: Bool { get async { granted } }
    func grantAccess(to folder: URL) async throws {
        guard folder.path == "/Users/example" else { throw NativeCleanupError.wrongFolder("/Users/example") }
        granted = true
    }
    func scan() async throws -> CleanupReport {
        guard granted else { throw NativeCleanupError.accessRequired("/Users/example") }
        return try await FixtureCleanupService().scan()
    }
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { try await scan() }
}
