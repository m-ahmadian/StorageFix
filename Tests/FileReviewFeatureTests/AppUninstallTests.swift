import ApplicationsFeature
import Foundation
import StorageFixCore
import Testing

@MainActor struct AppUninstallTests {
    actor FakeRelated: AppRelatedFilesProviding {
        var trashed: [String] = []
        func relatedFiles(bundleID: String, appName: String) async throws -> [RelatedFile] {
            [RelatedFile(path: "/L/Preferences/\(bundleID).plist", bytes: 10, location: "Preferences", matchedByName: false),
             RelatedFile(path: "/L/Caches/\(appName)", bytes: 90, location: "Caches", matchedByName: true)]
        }
        func moveToTrash(_ files: [RelatedFile]) async -> [String] { trashed += files.map(\.path); return [] }
    }

    @Test func `Reviewing preselects identifier matches only, and the Store edition trashes data but keeps the app`() async throws {
        let related = FakeRelated()
        let vm = ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false, related: related, runningBundleIDs: { [] })
        await vm.scan()
        let app = try #require(vm.applications.first)
        #expect(vm.canReview)
        await vm.review(app)
        #expect(vm.relatedFiles.count == 2 && vm.selectedRelated == ["/L/Preferences/\(app.bundleIdentifier).plist"])
        await vm.moveToTrash()
        #expect(await related.trashed == ["/L/Preferences/\(app.bundleIdentifier).plist"])
        #expect(vm.applications.contains(app) && vm.resultMessage?.contains("stays installed") == true)
    }

    @Test func `A running app is never touched`() async throws {
        let related = FakeRelated()
        let app = try #require(try await FixtureApplicationService().scan().first)
        let blocked = ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: true, related: related,
                                            runningBundleIDs: { [app.bundleIdentifier] })
        await blocked.scan(); await blocked.review(app); await blocked.moveToTrash()
        #expect(blocked.errorMessage?.contains("Quit") == true && blocked.applications.contains(app) && (await related.trashed).isEmpty)
    }
}
