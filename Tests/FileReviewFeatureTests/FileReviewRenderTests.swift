import AppKit
import CleanupFeature
import ApplicationsFeature
import StorageMapFeature
@testable import WorkspaceFeature
import DuplicateFeature
import LargeFilesFeature
import ScanComparisonFeature
@testable import ReviewQueueFeature
import StorageFixCore
import SwiftUI
import Testing

@MainActor
struct FileReviewRenderTests {
    @Test(arguments: [false, true])
    func `Given reviewed duplicates, when rendering in each appearance, then the review UI renders`(dark: Bool) async throws {
        let vm = DuplicateViewModel(service: RenderDuplicateService())
        await vm.scan()
        try render(DuplicateView(viewModel: vm), name: "duplicates", dark: dark)
    }
    @Test(arguments: [false, true])
    func `Given an unscanned folder, when rendering large files in each appearance, then the entry UI renders`(dark: Bool) throws {
        try render(LargeFilesView(viewModel: LargeFilesViewModel(scope: URL(fileURLWithPath: "/Users/example/Downloads"), service: FixtureFileService())), name: "large-files", dark: dark)
    }
    @Test(arguments: [false, true])
    func `Given the new workspace, when rendering each appearance, then the dashboard renders`(dark: Bool) async throws {
        let vm = fixtureWorkspace(); await vm.review(); vm.refreshDisk()
        try render(WorkspaceView(viewModel: vm), name: "workspace", dark: dark, width: 1240, height: 860)
    }
    @Test(arguments: [false, true])
    func `Given a scanned storage map, when rendering each appearance, then the explorer renders`(dark: Bool) throws {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: FixtureFileService())
        vm.acceptInventory([DuplicateFile(path: "/fixture/Images/a.jpg", bytes: 80_000_000), DuplicateFile(path: "/fixture/Exports/b.mov", bytes: 200_000_000), DuplicateFile(path: "/fixture/document.pdf", bytes: 50_000_000)], root: vm.root)
        try render(StorageMapView(viewModel: vm), name: "storage-map", dark: dark)
    }
    @Test(arguments: [false, true])
    func `Given scanned apps, when rendering each appearance, then application review renders`(dark: Bool) async throws {
        let vm = ApplicationsViewModel(service: FixtureApplicationService()); await vm.scan()
        try render(ApplicationsView(viewModel: vm), name: "applications", dark: dark)
    }

    @Test(arguments: [false, true])
    func `Given the minimum window size, when rendering each appearance, then review actions remain accessible`(dark: Bool) async throws {
        let vm = fixtureWorkspace(); await vm.review()
        try render(WorkspaceView(viewModel: vm), name: "workspace-minimum", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given the Store edition, when rendering the first launch, then folder access is explicit`(dark: Bool) throws {
        let root = URL(fileURLWithPath: "/fixture")
        let vm = WorkspaceViewModel(cleanup: CleanupViewModel(service: FixtureCleanupService()),
            duplicates: DuplicateViewModel(service: FixtureDuplicateService(), requiresFolderSelection: true),
            files: LargeFilesViewModel(scope: root, service: FixtureFileService(), requiresFolderSelection: true),
            map: StorageMapViewModel(root: root, service: FixtureFileService(), requiresFolderSelection: true),
            apps: ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false, requiresFolderSelection: true),
            defaults: UserDefaults(suiteName: "StorageFixStoreRender-\(UUID().uuidString)")!, edition: .appStore)
        try render(WorkspaceView(viewModel: vm), name: "store-first-launch", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given a partial review, when rendering the report, then error details and export actions render`(dark: Bool) async throws {
        let vm = fixtureWorkspace(failApps: true)
        await vm.review()
        let report = try #require(vm.latestReport)
        try render(ReviewReportView(report: report, openArea: { _ in }), name: "review-report", dark: dark, width: 640, height: 600)
    }

    @Test(arguments: [false, true])
    func `Given more than five map items, when rendering, then the remainder legend and totals render`(dark: Bool) async throws {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: MapInventoryFixture())
        await vm.scan()
        #expect(vm.chartSlices.last?.id == .remainder)
        try render(StorageMapView(viewModel: vm), name: "storage-map-remainder", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given partial coverage, map details remain readable at minimum size`(dark: Bool) async throws {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: RichInventoryFixture())
        await vm.scan()
        try render(StorageMapView(viewModel: vm), name: "storage-map-coverage", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given linked map selection, both visual styles render with breadcrumbs and filters`(dark: Bool) async throws {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: MapInventoryFixture())
        await vm.scan()
        vm.selectAngle(0)
        try render(StorageMapView(viewModel: vm), name: "storage-map-treemap-selection", dark: dark, width: 1080, height: 740)
        vm.setMapStyle(.ring)
        try render(StorageMapView(viewModel: vm), name: "storage-map-ring-selection", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given a two-level inventory, sunburst and linked list render at minimum size`(dark: Bool) async throws {
        let vm = StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: SunburstInventoryFixture())
        await vm.scan(); vm.setMapStyle(.sunburst)
        try render(StorageMapView(viewModel: vm), name: "storage-map-sunburst", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given queued files and a partial failure, queue review and outcomes render`(dark: Bool) async throws {
        let fixture = QueueFeatureFiles(), queue = featureQueue(operations: QueueFeatureOperations(fail: true))
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: Set(fixture.files.map(\.path)), origin: .files)
        let vm = ReviewQueueViewModel(queue: queue, reportService: QueueReportService())
        try render(ReviewQueueView(viewModel: vm), name: "review-queue", dark: dark, width: 860, height: 740)
        vm.requestConfirmation(); await vm.execute()
        try render(ReviewQueueView(viewModel: vm), name: "review-queue-blocked", dark: dark, width: 860, height: 740)
    }

    @Test(arguments: [false, true])
    func `Given completed outcomes, export preview exposes redaction controls before saving`(dark: Bool) async throws {
        let fixture = QueueFeatureFiles(), queue = featureQueue()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        let vm = ReviewQueueViewModel(queue: queue, reportService: QueueReportService())
        await vm.prepareReport()
        try render(QueueReportExportView(viewModel: vm), name: "queue-export-preview", dark: dark, width: 640, height: 600)
    }

    @Test(arguments: [false, true])
    func `Given saved metadata and a fresh scan, comparison warnings and differences render`(dark: Bool) async throws {
        let session = ScanComparisonSession()
        let root = URL(fileURLWithPath: "/Users/example/Downloads")
        session.receive(InventoryScan(sessionID: UUID(), root: root, options: InventoryOptions(), files: [
            DuplicateFile(path: root.appending(path: "Old Export.mov").path, bytes: 80_000_000)]))
        let vm = ScanComparisonViewModel(session: session, service: ScanSnapshotService())
        await vm.captureBaseline()
        var coverage = InventoryCoverage(); coverage.record(.init(path: root.appending(path: "Restricted").path, reason: .inaccessible))
        session.receive(InventoryScan(sessionID: UUID(), root: root, options: InventoryOptions(), files: [
            DuplicateFile(path: root.appending(path: "New Export.mov").path, bytes: 120_000_000)], coverage: coverage))
        await vm.compare()
        try render(ScanComparisonView(viewModel: vm), name: "scan-comparison", dark: dark, width: 1080, height: 740)
    }

    @Test(arguments: [false, true])
    func `All production navigation destinations fit the minimum workspace`(dark: Bool) throws {
        let comparison = ScanComparisonViewModel(session: ScanComparisonSession(), service: ScanSnapshotService())
        let vm = fixtureWorkspace(queue: ReviewQueueViewModel(queue: featureQueue()), comparison: comparison)
        vm.select(.comparison)
        try render(WorkspaceView(viewModel: vm), name: "workspace-comparison-minimum", dark: dark, width: 1080, height: 740)
    }

    private func render(_ view: some View, name: String, dark: Bool, width: CGFloat = 980, height: CGFloat = 760) throws {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let hosting = NSHostingView(rootView: view.tint(.blue).environment(\.colorScheme, dark ? .dark : .light))
        hosting.frame = frame
        hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        #expect(hosting.frame.width <= frame.width && hosting.frame.height <= frame.height)
        window.displayIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: frame))
        hosting.cacheDisplay(in: frame, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        #expect(data.count > 1000)
        if let output = ProcessInfo.processInfo.environment["STORAGEFIX_RENDER_DIRECTORY"] {
            try data.write(to: URL(fileURLWithPath: output).appending(path: "\(name)-\(dark ? "dark" : "light").png"))
        }
    }
}
private struct RenderDuplicateService: DuplicateServiceProtocol {
    func scan() async throws -> [DuplicateGroup] {
        [DuplicateGroup(id: "fixture", original: DuplicateFile(path: "/Users/example/Documents/Project/Proposal.pdf", bytes: 8_000_000),
            duplicates: [DuplicateFile(path: "/Users/example/Downloads/Proposal copy.pdf", bytes: 8_000_000)])]
    }
    func remove(paths: Set<String>) async throws {}
    func reveal(path: String) {}
}
