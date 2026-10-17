import Foundation

public enum ReviewOrigin: String, Codable, CaseIterable, Sendable {
    case map = "Storage map", files = "File review", duplicates = "Duplicate comparison"
}

public struct ReviewQueueItem: Identifiable, Equatable, Sendable {
    public let file: DuplicateFile
    public let root: URL
    public let origins: Set<ReviewOrigin>
    public let requiresRescan: Bool
    public var id: String { file.path }
    public init(file: DuplicateFile, root: URL, origins: Set<ReviewOrigin>, requiresRescan: Bool = false) {
        self.file = file; self.root = root; self.origins = origins; self.requiresRescan = requiresRescan
    }
}

public struct ReviewDuplicateProtection: Equatable, Sendable {
    public struct ID: Hashable, Sendable {
        public let digest: String
        public let paths: [String]
    }
    public let digest: String
    public let root: URL
    public let kept: DuplicateFile
    public let members: [DuplicateFile]
    public let id: ID
    public init(group: DuplicateGroup, root: URL) {
        digest = group.id; self.root = root; kept = group.original; members = [group.original] + group.duplicates
        id = ID(digest: group.id, paths: ([group.original] + group.duplicates).map(\.path).sorted())
    }
    func excludingMoved(_ paths: Set<String>) -> ReviewDuplicateProtection {
        let group = DuplicateGroup(id: digest, original: kept, duplicates: members.filter { $0.path != kept.path && !paths.contains($0.path) })
        return ReviewDuplicateProtection(group: group, root: root)
    }
}

public enum ReviewQueueItemStatus: String, Codable, Sendable { case moved, failed, blocked, cancelled }

public struct ReviewQueueOutcome: Identifiable, Equatable, Sendable {
    public let path: String
    public let logicalBytes: Int64
    public let status: ReviewQueueItemStatus
    public let message: String
    public var id: String { path }
    public init(path: String, logicalBytes: Int64, status: ReviewQueueItemStatus, message: String) {
        self.path = path; self.logicalBytes = logicalBytes; self.status = status; self.message = message
    }
}

public struct ReviewQueueRun: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let outcomes: [ReviewQueueOutcome]
    /// Observed volume free space; nil when no volume service was available.
    public let freeSpace: FreeSpaceMeasurement?
    public init(id: UUID = UUID(), date: Date = Date(), outcomes: [ReviewQueueOutcome], freeSpace: FreeSpaceMeasurement? = nil) {
        self.id = id; self.date = date; self.outcomes = outcomes; self.freeSpace = freeSpace
    }
    public var movedCount: Int { outcomes.filter { $0.status == .moved }.count }
    func replacingFreeSpace(_ value: FreeSpaceMeasurement?) -> ReviewQueueRun {
        ReviewQueueRun(id: id, date: date, outcomes: outcomes, freeSpace: value)
    }
}

public struct ReviewQueueSnapshot: Equatable, Sendable {
    public let revision: UUID
    public let items: [ReviewQueueItem]
    public let blockers: [String: String]
    public let isExecuting: Bool
    public let completedCount: Int
    public let lastRun: ReviewQueueRun?
    public init(revision: UUID = UUID(), items: [ReviewQueueItem] = [], blockers: [String: String] = [:], isExecuting: Bool = false,
                completedCount: Int = 0, lastRun: ReviewQueueRun? = nil) {
        self.revision = revision; self.items = items; self.blockers = blockers; self.isExecuting = isExecuting
        self.completedCount = completedCount; self.lastRun = lastRun
    }
}

public struct ReviewQueueAddResult: Equatable, Sendable {
    public let addedCount: Int
    public let existingCount: Int
    public let rejections: [String: String]
    public var message: String {
        "Added \(addedCount) files to Review Queue · \(existingCount) already queued · \(rejections.count) not added."
    }
}
