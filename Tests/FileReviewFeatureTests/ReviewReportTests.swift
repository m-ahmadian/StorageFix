import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import Foundation
import LargeFilesFeature
import StorageFixCore
import StorageMapFeature
import Testing
@testable import WorkspaceFeature

@MainActor
struct ReviewReportTests {
    @Test func `Given completed scans, when reporting, then inventories have separate counts scopes and bytes`() async throws {
        let vm = fixtureWorkspace()
        await vm.review()
        let report = try #require(vm.latestReport)
        #expect(report.areas.map(\.section) == [.files, .duplicates, .apps, .cleanup])
        #expect(report.areas.map(\.bytes) == [160_000_000, 12_000_000, 120_000_000, 3_400_000_000])
        #expect(report.areas.map(\.itemCount) == [3, 1, 1, 1])
        #expect(report.folder == "/fixture")
        #expect(report.needsAttention == false)
        #expect(report.text.contains("not a total of reclaimable space"))
    }

    @Test func `Given an application scan failure, when reporting, then its error replaces totals and other results remain`() async throws {
        let vm = fixtureWorkspace(failApps: true)
        await vm.review()
        let report = try #require(vm.latestReport)
        let app = try #require(report.areas.first { $0.section == .apps })
        #expect(report.needsAttention)
        #expect(app.error != nil && app.bytes == nil && app.itemCount == nil)
        #expect(report.areas.first?.bytes == 160_000_000)
        #expect(report.text.contains("Attention:"))
    }

    @Test func `Given a report, when filters and live results change, then the snapshot stays accurate`() async throws {
        let vm = fixtureWorkspace()
        await vm.review()
        let report = try #require(vm.latestReport)
        vm.files.minimumMB = 999; vm.files.query = "missing"
        #expect(vm.files.visibleFiles.isEmpty)
        #expect(vm.fileInventoryDescription == "3 files inventoried")
        #expect(vm.latestReport == report)
        vm.files.chooseFolder(URL(fileURLWithPath: "/elsewhere"))
        #expect(vm.latestReport == report)
        vm.chooseReviewFolder(URL(fileURLWithPath: "/new"))
        #expect(vm.latestReport == nil)
    }

    @Test func `Given an authorized Store folder without the Home grant, when reporting, then only folder scans appear`() async throws {
        let (vm, defaults, suite) = try workspace(service: FixtureFileService(), edition: .appStore)
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.review()
        let report = try #require(vm.latestReport)
        #expect(report.areas.map(\.section) == [.files, .duplicates])
        #expect(vm.apps.hasScanned == false && vm.cleanup.hasScanned == false)
    }

    @Test(arguments: [false, true])
    func `Given a pending scan, when completing or cancelling, then loading and report state are consistent`(cancel: Bool) async throws {
        let service = PausedReportFileService()
        let (vm, defaults, suite) = try workspace(service: service)
        defer { defaults.removePersistentDomain(forName: suite) }
        let task = Task { await vm.review() }
        await service.waitUntilScanning()
        #expect(vm.isReviewing && vm.latestReport == nil && vm.completedSteps == 0)
        #expect(vm.canReview == false)
        vm.select(.apps)
        #expect(vm.selectedSection == .overview)
        if cancel { task.cancel() }
        await service.resume()
        await task.value
        #expect(vm.isReviewing == false)
        if cancel {
            #expect(vm.latestReport == nil && vm.lastReviewDate == nil && vm.activity.isEmpty)
            #expect(vm.reviewMessage?.contains("cancelled") == true)
        } else {
            #expect(vm.latestReport != nil && vm.completedSteps == vm.reviewStageCount)
        }
    }

    @Test func `Given an area needing attention, when opening it, then navigation targets that area`() async {
        let vm = fixtureWorkspace(failApps: true)
        await vm.review()
        vm.select(.apps)
        #expect(vm.selectedSection == .apps)
    }

    @Test func `Given a Store workspace, Cleanup opens and asks for the Home folder before scanning`() throws {
        let (vm, defaults, suite) = try workspace(service: FixtureFileService(), edition: .appStore)
        defer { defaults.removePersistentDomain(forName: suite) }
        vm.select(.cleanup)
        #expect(vm.selectedSection == .cleanup && vm.cleanup.needsAccess && !vm.cleanup.hasScanned)
    }

    @Test func `Given several completed reviews, when expanding history, then all retained entries are accessible`() async {
        let vm = fixtureWorkspace()
        for _ in 0..<5 { await vm.review() }
        #expect(vm.hasMoreActivity)
        #expect(vm.visibleActivity(expanded: false).count == 3)
        #expect(vm.visibleActivity(expanded: true).count == 5)
        vm.clearActivity()
        #expect(vm.hasMoreActivity == false)
        #expect(vm.visibleActivity(expanded: true).isEmpty)
    }

    private func workspace(service: any FileBrowserServiceProtocol, edition: DistributionMode = .direct) throws -> (WorkspaceViewModel, UserDefaults, String) {
        let suite = "StorageFixReport-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let root = URL(fileURLWithPath: "/fixture")
        let vm = WorkspaceViewModel(cleanup: CleanupViewModel(service: edition == .appStore ? StoreAccessCleanup() as any CleanupServiceProtocol : FixtureCleanupService()),
            duplicates: DuplicateViewModel(service: FixtureDuplicateService(), scopeDescription: root.path),
            files: LargeFilesViewModel(scope: root, service: service), map: StorageMapViewModel(root: root, service: FixtureFileService()),
            apps: ApplicationsViewModel(service: FixtureApplicationService()), defaults: defaults, edition: edition, includesDuplicateComparison: true)
        return (vm, defaults, suite)
    }
}

private actor PausedReportFileService: FileBrowserServiceProtocol {
    private var started = false
    private var scanWaiter: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?

    func scan(in root: URL) async throws -> [DuplicateFile] {
        started = true
        startWaiter?.resume(); startWaiter = nil
        await withCheckedContinuation { scanWaiter = $0 }
        try Task.checkCancellation()
        return []
    }
    func waitUntilScanning() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func resume() { scanWaiter?.resume(); scanWaiter = nil }
    func moveToTrash(paths: Set<String>) async throws {}
}
