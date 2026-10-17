import Foundation

public struct QueueOutcomeReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let operationID: UUID
    public let date: Date
    public let includesPaths: Bool
    public let selectedLogicalBytes: Int64
    public let movedLogicalBytes: Int64
    public let spaceRecovery: String
    /// Whole-volume observations; nil when not measured. Never attributed to moved files.
    public let freeSpaceBeforeBytes: Int64?
    public let freeSpaceAfterBytes: Int64?
    public let freeSpaceChangeBytes: Int64?
    public let freeSpaceMeasuredAt: Date?
    public let items: [Item]
    public struct Item: Codable, Equatable, Sendable {
        public let label: String
        public let path: String?
        public let logicalBytes: Int64
        public let status: ReviewQueueItemStatus
        public let detail: String
    }
    public init(run: ReviewQueueRun, includesPaths: Bool) {
        schemaVersion = 2; operationID = run.id; date = run.date; self.includesPaths = includesPaths
        selectedLogicalBytes = run.outcomes.reduce(0) { $0 + $1.logicalBytes }
        movedLogicalBytes = run.outcomes.filter { $0.status == .moved }.reduce(0) { $0 + $1.logicalBytes }
        let measurement = run.freeSpace.flatMap { $0.isMeasured ? $0 : nil }
        freeSpaceBeforeBytes = measurement?.beforeBytes; freeSpaceAfterBytes = measurement?.afterBytes
        freeSpaceChangeBytes = measurement?.changeBytes; freeSpaceMeasuredAt = measurement?.measuredAt
        spaceRecovery = Self.spaceRecovery(run.freeSpace)
        items = run.outcomes.enumerated().map { index, outcome in
            Item(label: "Item \(index + 1)", path: includesPaths ? outcome.path : nil,
                logicalBytes: outcome.logicalBytes, status: outcome.status,
                detail: includesPaths ? outcome.message : Self.redactedDetail(outcome.status))
        }
    }
    static let notMeasured = "Not measured. Logical bytes moved to Trash are not recovered disk space."
    static let volumeCaveat = "This observes the whole volume: other apps, local snapshots and purgeable storage also change it, and files in Trash usually keep using space until Trash is emptied in Finder."
    private static func spaceRecovery(_ measurement: FreeSpaceMeasurement?) -> String {
        guard let measurement else { return notMeasured }
        guard measurement.isMeasured, let change = measurement.changeBytes,
              let before = measurement.beforeBytes, let after = measurement.afterBytes else {
            return "Not measured. \(measurement.unavailableReason ?? FreeSpaceProbe.unreadable) Logical bytes moved to Trash are not recovered disk space."
        }
        let sign = change > 0 ? "+" : ""
        return "Measured volume free space changed by \(sign)\(change) bytes (\(before) before, \(after) at \(measurement.measuredAt.ISO8601Format())). \(volumeCaveat)"
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
