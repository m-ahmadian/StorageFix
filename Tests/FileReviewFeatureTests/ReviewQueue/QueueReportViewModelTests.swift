import Foundation
import ReviewQueueFeature
import StorageFixCore
import Testing

@MainActor struct QueueReportViewModelTests {
    @Test(arguments: [false, true])
    func `Report preparation has loading state and discards results after dismissal`(dismiss: Bool) async throws {
        let service = PausedReportService()
        let vm = try await makeViewModel(service: service)
        #expect(!vm.reportIncludesPaths && vm.canExport)
        let task = Task { await vm.prepareReport() }
        await service.waitUntilStarted()
        #expect(vm.isPreparingReport && vm.reportDocument == nil)
        if dismiss { vm.clearReport() }
        await service.finish(); await task.value
        #expect(!vm.isPreparingReport)
        #expect(dismiss ? vm.reportDocument == nil : vm.reportDocument?.text == "Report fixture")
    }
    @Test func `Report service errors clear loading and show an actionable failure`() async throws {
        let vm = try await makeViewModel(service: FailedReportService())
        await vm.prepareReport()
        #expect(!vm.isPreparingReport && vm.reportDocument == nil && vm.reportError != nil)
    }
    private func makeViewModel(service: any QueueReportServiceProtocol) async throws -> ReviewQueueViewModel {
        let queue = featureQueue(), fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        return ReviewQueueViewModel(queue: queue, reportService: service)
    }
}

private struct FailedReportService: QueueReportServiceProtocol {
    func makeReport(run: ReviewQueueRun, includesPaths: Bool, format: QueueReportFormat) async throws -> QueueReportDocument {
        throw CocoaError(.fileWriteUnknown)
    }
}
private actor PausedReportService: QueueReportServiceProtocol {
    private var started = false
    private var observer: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func makeReport(run: ReviewQueueRun, includesPaths: Bool, format: QueueReportFormat) async throws -> QueueReportDocument {
        started = true; observer?.resume(); observer = nil
        await withCheckedContinuation { waiter = $0 }
        return QueueReportDocument(text: "Report fixture", format: format, operationID: run.id)
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() { waiter?.resume(); waiter = nil }
}
