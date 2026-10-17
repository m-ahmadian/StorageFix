import Foundation

public protocol QueueReportServiceProtocol: Sendable {
    func makeReport(run: ReviewQueueRun, includesPaths: Bool, format: QueueReportFormat) async throws -> QueueReportDocument
}

public actor QueueReportService: QueueReportServiceProtocol {
    public init() {}
    public func makeReport(run: ReviewQueueRun, includesPaths: Bool, format: QueueReportFormat) throws -> QueueReportDocument {
        try Task.checkCancellation()
        let report = QueueOutcomeReport(run: run, includesPaths: includesPaths)
        let text: String
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            guard let json = String(data: data, encoding: .utf8) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            text = json
        case .csv: text = csv(report)
        case .text: text = plainText(report)
        }
        try Task.checkCancellation()
        return QueueReportDocument(text: text, format: format, operationID: run.id)
    }
    private func plainText(_ report: QueueOutcomeReport) -> String {
        let header = ["StorageFix queue operation", "Date: \(report.date.ISO8601Format())", "Operation: \(report.operationID)",
            "Selected logical bytes: \(report.selectedLogicalBytes)", "Moved logical bytes: \(report.movedLogicalBytes)", report.spaceRecovery,
            report.includesPaths ? "Full paths included. Review before sharing." : "Paths and identifying error details omitted."]
        let items = report.items.map { "\($0.path ?? $0.label) · \($0.status.rawValue) · \($0.logicalBytes) logical bytes\n\($0.detail)" }
        return (header + items).joined(separator: "\n\n")
    }
    private func csv(_ report: QueueOutcomeReport) -> String {
        let header = "operation_id,date,item,status,logical_bytes,path,detail,space_recovery"
        let rows = report.items.map { item in
            [report.operationID.uuidString, report.date.ISO8601Format(), item.label, item.status.rawValue,
             String(item.logicalBytes), item.path ?? "", item.detail, report.spaceRecovery].map(csvCell).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }
    private func csvCell(_ text: String) -> String {
        let first = text.drop(while: { $0.isWhitespace }).first
        let needsProtection = first.map { "=+-@".contains($0) } ?? false
        let value = (needsProtection ? "'" : "") + text
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
