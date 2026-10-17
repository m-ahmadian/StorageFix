import Foundation

public struct InventoryOptions: Equatable, Sendable {
    public var includesHiddenFiles = false
    public var includesPackageContents = false
    public init() {}
}

public enum InventoryIssueReason: String, CaseIterable, Sendable {
    case inaccessible, disappeared, changed, hidden, package, symbolicLink, cloudPlaceholder, sharedLink, unknownIdentity, unknownSize, unsupported
}

public struct InventoryIssue: Equatable, Sendable {
    public let path: String
    public let reason: InventoryIssueReason
    public init(path: String, reason: InventoryIssueReason) { self.path = path; self.reason = reason }
}

/// Counts are observed entries, never an estimate of descendants inside skipped folders.
public struct InventoryCoverage: Equatable, Sendable {
    public private(set) var counts: [InventoryIssueReason: Int] = [:]
    public private(set) var examples: [InventoryIssue] = []
    public static let exampleLimit = 20
    public init() {}
    public mutating func record(_ issue: InventoryIssue) {
        counts[issue.reason, default: 0] += 1
        if examples.count < Self.exampleLimit { examples.append(issue) }
    }
    public var hasReadErrors: Bool {
        [.inaccessible, .disappeared, .changed, .unknownSize, .unknownIdentity].contains { counts[$0, default: 0] > 0 }
    }
}

public struct InventoryProgress: Equatable, Sendable {
    public let sessionID: UUID
    public let visitedCount: Int
    public let fileCount: Int
    public init(sessionID: UUID, visitedCount: Int, fileCount: Int) {
        self.sessionID = sessionID; self.visitedCount = visitedCount; self.fileCount = fileCount
    }
}

public struct InventoryScan: Equatable, Sendable {
    public let sessionID: UUID
    public let root: URL
    public let options: InventoryOptions
    public let files: [DuplicateFile]
    public let coverage: InventoryCoverage
    public let wasCancelled: Bool
    /// False for adapters whose array-only source cannot report coverage.
    public let coverageAvailable: Bool
    public let mapIndex: StorageMapIndex?
    public let volume: InventoryVolume?
    public func cancelled() -> InventoryScan {
        InventoryScan(sessionID: sessionID, root: root, options: options, files: files, coverage: coverage,
            wasCancelled: true, coverageAvailable: coverageAvailable, volume: volume, mapIndex: mapIndex)
    }
    public var logicalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    public var knownAllocatedBytes: Int64 { files.reduce(0) { $0 + ($1.allocatedBytes ?? 0) } }
    public var unknownAllocatedCount: Int { files.filter { $0.allocatedBytes == nil }.count }
    public init(sessionID: UUID, root: URL, options: InventoryOptions, files: [DuplicateFile],
                coverage: InventoryCoverage = InventoryCoverage(), wasCancelled: Bool = false,
                coverageAvailable: Bool = true, volume: InventoryVolume? = nil, mapIndex: StorageMapIndex? = nil) {
        self.sessionID = sessionID; self.root = root; self.options = options; self.files = files
        self.coverage = coverage; self.wasCancelled = wasCancelled
        self.coverageAvailable = coverageAvailable; self.volume = volume; self.mapIndex = mapIndex
    }
}

public struct InventoryVolume: Equatable, Sendable {
    public let name: String?
    public let capacityBytes: Int64?
    public let availableBytes: Int64?
    public let isReadOnly: Bool?
    /// Stable volume identity (APFS/HFS UUID) when macOS reports one; display names can repeat across volumes.
    public let identifier: String?
    public init(name: String?, capacityBytes: Int64?, availableBytes: Int64?, isReadOnly: Bool?, identifier: String? = nil) {
        self.name = name; self.capacityBytes = capacityBytes; self.availableBytes = availableBytes; self.isReadOnly = isReadOnly
        self.identifier = identifier
    }
}
