import Foundation

/// Descriptive metadata only. A snapshot never authorizes filesystem operations.
public struct ScanSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let id: UUID
    public let date: Date
    public let rootPath: String
    public let volumeName: String?
    public let includesHiddenFiles: Bool
    public let includesPackageContents: Bool
    public let wasCancelled: Bool
    public let coverageAvailable: Bool
    public let coverageCounts: [String: Int]
    public let entries: [Entry]
    public struct Entry: Codable, Equatable, Identifiable, Sendable {
        public let relativePath: String
        public let logicalBytes: Int64
        public let modifiedAtMilliseconds: Double?
        public var id: String { relativePath }
    }
    public var logicalBytes: Int64 { entries.reduce(0) { $0 + $1.logicalBytes } }
    public var hasIncompleteCoverage: Bool {
        wasCancelled || !coverageAvailable || coverageCounts.contains { key, count in
            count > 0 && !["hidden", "package", "symbolicLink", "sharedLink"].contains(key)
        }
    }
    public init(scan: InventoryScan, date: Date = Date()) {
        version = 1; id = UUID(); self.date = date
        rootPath = scan.root.standardizedFileURL.path; volumeName = scan.volume?.name
        includesHiddenFiles = scan.options.includesHiddenFiles
        includesPackageContents = scan.options.includesPackageContents
        wasCancelled = scan.wasCancelled; coverageAvailable = scan.coverageAvailable
        coverageCounts = Dictionary(uniqueKeysWithValues: scan.coverage.counts.map { ($0.key.rawValue, $0.value) })
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        entries = scan.files.map { file in
            Entry(relativePath: file.path.hasPrefix(prefix) ? String(file.path.dropFirst(prefix.count)) : file.path,
                  logicalBytes: file.bytes, modifiedAtMilliseconds: file.modifiedAt.map { ($0.timeIntervalSince1970 * 1_000).rounded() })
        }.sorted { $0.relativePath < $1.relativePath }
    }
}
