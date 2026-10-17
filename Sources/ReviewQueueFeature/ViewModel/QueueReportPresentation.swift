import Foundation
import StorageFixCore

extension ReviewQueueViewModel {
    private static var previewCharacterLimit: Int { 20_000 }
    public var reportPreview: String {
        guard let text = reportDocument?.text else { return "Generate a preview to inspect the exported fields." }
        guard text.count > Self.previewCharacterLimit else { return text }
        return String(text.prefix(Self.previewCharacterLimit)) + "\n\nPreview shortened for responsiveness. Saving exports the full report, including every selected item."
    }
    public var canExport: Bool { reportService != nil && !isExecuting && snapshot.lastRun != nil }
    public func setReportFormat(_ value: QueueReportFormat) { reportFormat = value; clearReport() }
    public func setReportIncludesPaths(_ value: Bool) { reportIncludesPaths = value; clearReport() }
    public func clearReport() { reportGeneration = nil; reportDocument = nil; reportError = nil; isPreparingReport = false }
    public func prepareReport() async {
        guard canExport, let run = snapshot.lastRun, let reportService else { return }
        let generation = UUID()
        reportGeneration = generation; isPreparingReport = true; reportError = nil; reportDocument = nil
        defer { if reportGeneration == generation { isPreparingReport = false } }
        do {
            let document = try await reportService.makeReport(run: run, includesPaths: reportIncludesPaths, format: reportFormat)
            try Task.checkCancellation()
            guard reportGeneration == generation else { return }
            reportDocument = document
        } catch is CancellationError { }
        catch { if reportGeneration == generation { reportError = error.localizedDescription } }
    }
    public func finishedExport(_ result: Result<URL, Error>) {
        switch result {
        case .success: reportError = nil
        case .failure(let error):
            if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError { return }
            reportError = "Could not save the report: \(error.localizedDescription)"
        }
    }
}
