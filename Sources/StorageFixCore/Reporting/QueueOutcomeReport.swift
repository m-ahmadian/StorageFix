import Foundation

public struct QueueOutcomeReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let operationID: UUID
    public let date: Date
    public let includesPaths: Bool
    public let selectedLogicalBytes: Int64
    public let movedLogicalBytes: Int64
    public let spaceRecovery: String
    public let items: [Item]
    public struct Item: Codable, Equatable, Sendable {
        public let label: String
        public let path: String?
        public let logicalBytes: Int64
        public let status: ReviewQueueItemStatus
        public let detail: String
    }
    public init(run: ReviewQueueRun, includesPaths: Bool) {
        schemaVersion = 1; operationID = run.id; date = run.date; self.includesPaths = includesPaths
        selectedLogicalBytes = run.outcomes.reduce(0) { $0 + $1.logicalBytes }
        movedLogicalBytes = run.outcomes.filter { $0.status == .moved }.reduce(0) { $0 + $1.logicalBytes }
        spaceRecovery = "Not measured. Logical bytes moved to Trash are not recovered disk space."
        items = run.outcomes.enumerated().map { index, outcome in
            Item(label: "Item \(index + 1)", path: includesPaths ? outcome.path : nil,
                logicalBytes: outcome.logicalBytes, status: outcome.status,
                detail: includesPaths ? outcome.message : Self.redactedDetail(outcome.status))
        }
    }
    private static func redactedDetail(_ status: ReviewQueueItemStatus) -> String {
        switch status {
        case .moved: "Moved to Trash. Restore through Finder where available."
        case .failed: "Move was not confirmed. Inspect details in StorageFix and scan again."
        case .blocked: "Batch validation failed before changes. Inspect details in StorageFix."
        case .cancelled: "Cancelled before this item was moved."
        }
    }
}

public enum QueueReportFormat: String, CaseIterable, Identifiable, Sendable {
    case text = "Text", json = "JSON", csv = "CSV"
    public var id: Self { self }
    public var fileExtension: String { switch self { case .text: "txt"; case .json: "json"; case .csv: "csv" } }
}

public struct QueueReportDocument: Equatable, Sendable {
    public let text: String
    public let format: QueueReportFormat
    public let operationID: UUID
    public init(text: String, format: QueueReportFormat, operationID: UUID) {
        self.text = text; self.format = format; self.operationID = operationID
    }
}
