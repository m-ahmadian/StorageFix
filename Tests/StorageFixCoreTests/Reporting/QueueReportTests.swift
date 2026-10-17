import Foundation
import StorageFixCore
import Testing

struct QueueReportTests {
    private var run: ReviewQueueRun {
        ReviewQueueRun(date: Date(timeIntervalSince1970: 100), outcomes: [
            ReviewQueueOutcome(path: "/private/person/Tax, \"draft\".pdf", logicalBytes: 100, status: .moved, message: "Moved /private/person/Tax"),
            ReviewQueueOutcome(path: "/private/person/failure", logicalBytes: 200, status: .failed, message: "\t=HYPERLINK(\"https://example.invalid\")"),
            ReviewQueueOutcome(path: "/private/person/cancelled", logicalBytes: 50, status: .cancelled, message: "Cancelled /private/person"),
            ReviewQueueOutcome(path: "/private/person/blocked", logicalBytes: 10, status: .blocked, message: "Blocked /private/person")])
    }
    @Test(arguments: QueueReportFormat.allCases)
    func `Default exports omit paths and identifying error details across every format`(format: QueueReportFormat) async throws {
        let operation = run
        let document = try await QueueReportService().makeReport(run: operation, includesPaths: false, format: format)
        #expect(!document.text.contains("/private/person") && !document.text.contains("Tax"))
        #expect(!document.text.contains("HYPERLINK"))
        #expect(document.text.contains("Not measured"))
        #expect(document.operationID == operation.id)
    }
    @Test func `JSON reconciles selected and moved logical bytes without inventing recovered space`() async throws {
        let document = try await QueueReportService().makeReport(run: run, includesPaths: true, format: .json)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(QueueOutcomeReport.self, from: Data(document.text.utf8))
        #expect(report.selectedLogicalBytes == 360 && report.movedLogicalBytes == 100)
        #expect(report.items.map(\.status) == [.moved, .failed, .cancelled, .blocked])
        #expect(report.includesPaths && report.items.first?.path == "/private/person/Tax, \"draft\".pdf")
        #expect(report.spaceRecovery.contains("not recovered disk space"))
    }
    @Test func `CSV escapes filenames and prevents spreadsheet formula execution`() async throws {
        let document = try await QueueReportService().makeReport(run: run, includesPaths: true, format: .csv)
        #expect(document.text.contains("\"/private/person/Tax, \"\"draft\"\".pdf\""))
        #expect(document.text.contains("'\t=HYPERLINK"))
        #expect(document.text.contains("\r\n"))
    }
}
