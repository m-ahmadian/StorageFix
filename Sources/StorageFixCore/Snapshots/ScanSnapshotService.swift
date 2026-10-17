import Foundation

public protocol ScanSnapshotServiceProtocol: Sendable {
    func capture(_ scan: InventoryScan) async throws -> ScanSnapshot
    func read(from url: URL) async throws -> ScanSnapshot
    func document(for snapshot: ScanSnapshot) async throws -> String
    func compare(baseline: ScanSnapshot, current: ScanSnapshot) async throws -> ScanComparison
}

public actor ScanSnapshotService: ScanSnapshotServiceProtocol {
    private enum Limits { static let documentBytes = 64 * 1024 * 1024; static let entries = 100_000; static let pathLength = 32_768 }
    public init() {}
    public func capture(_ scan: InventoryScan) async throws -> ScanSnapshot {
        try Task.checkCancellation()
        let snapshot = ScanSnapshot(scan: scan)
        try validate(snapshot)
        return snapshot
    }
    public func read(from url: URL) async throws -> ScanSnapshot {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw ScanSnapshotError.invalidDocument }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Limits.documentBytes + 1) ?? Data()
        guard data.count <= Limits.documentBytes else { throw ScanSnapshotError.tooLarge }
        try Task.checkCancellation()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let snapshot: ScanSnapshot
        do { snapshot = try decoder.decode(ScanSnapshot.self, from: data) }
        catch { throw ScanSnapshotError.invalidDocument }
        try validate(snapshot)
        return snapshot
    }
    public func document(for snapshot: ScanSnapshot) async throws -> String {
        try validate(snapshot)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        guard data.count <= Limits.documentBytes else { throw ScanSnapshotError.tooLarge }
        return String(decoding: data, as: UTF8.self)
    }
    private func validate(_ snapshot: ScanSnapshot) throws {
        guard snapshot.version == 1 else { throw ScanSnapshotError.unsupportedVersion }
        guard snapshot.entries.count <= Limits.entries else { throw ScanSnapshotError.tooLarge }
        guard snapshot.rootPath.hasPrefix("/"), snapshot.rootPath.utf8.count <= Limits.pathLength,
              !snapshot.rootPath.contains("\0"), URL(fileURLWithPath: snapshot.rootPath).standardizedFileURL.path == snapshot.rootPath,
              snapshot.coverageCounts.values.allSatisfy({ $0 >= 0 }) else { throw ScanSnapshotError.invalidDocument }
        var paths: Set<String> = [], total: Int64 = 0
        for entry in snapshot.entries {
            try Task.checkCancellation()
            let components = entry.relativePath.split(separator: "/", omittingEmptySubsequences: false)
            guard entry.logicalBytes >= 0, entry.modifiedAtMilliseconds?.isFinite != false, entry.relativePath.utf8.count <= Limits.pathLength,
                  !entry.relativePath.contains("\0"), components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  paths.insert(entry.relativePath).inserted else { throw ScanSnapshotError.invalidDocument }
            let sum = total.addingReportingOverflow(entry.logicalBytes)
            guard !sum.overflow else { throw ScanSnapshotError.invalidDocument }
            total = sum.partialValue
        }
    }
    public func compare(baseline: ScanSnapshot, current: ScanSnapshot) async throws -> ScanComparison {
        try validate(baseline); try validate(current)
        guard baseline.rootPath == current.rootPath else { throw ScanSnapshotError.differentScope }
        guard baseline.includesHiddenFiles == current.includesHiddenFiles,
              baseline.includesPackageContents == current.includesPackageContents else { throw ScanSnapshotError.differentOptions }
        let before = Dictionary(uniqueKeysWithValues: baseline.entries.map { ($0.relativePath, $0) })
        let after = Dictionary(uniqueKeysWithValues: current.entries.map { ($0.relativePath, $0) })
        var items: [ScanComparison.Item] = [], unchanged = 0
        for path in Set(before.keys).union(after.keys).sorted() {
            try Task.checkCancellation()
            let old = before[path], new = after[path]
            if old == new { unchanged += 1; continue }
            let change: ScanComparison.Change = old == nil ? .newlyObserved : (new == nil ? .noLongerObserved : .metadataChanged)
            items.append(.init(path: path, change: change, beforeBytes: old?.logicalBytes, afterBytes: new?.logicalBytes))
        }
        return ScanComparison(baselineID: baseline.id, currentID: current.id, beforeBytes: baseline.logicalBytes,
            afterBytes: current.logicalBytes, unchangedCount: unchanged, warnings: warnings(baseline, current), items: items)
    }
    private func warnings(_ baseline: ScanSnapshot, _ current: ScanSnapshot) -> [String] {
        var warnings = ["Metadata comparison only: missing entries do not prove deletion, and logical-size changes do not measure recovered space. Renames appear as newly/no longer observed paths.",
                        "The folder path must match. A saved snapshot cannot verify that a reconnected volume is the same physical device."]
        if baseline.hasIncompleteCoverage || current.hasIncompleteCoverage {
            warnings.append("One or both scans are incomplete. Permissions, placeholders, errors or cancellation can hide entries; differences may reflect coverage changes.")
        }
        if baseline.coverageCounts != current.coverageCounts { warnings.append("Excluded or unreadable entry counts changed between scans. Review scan coverage before interpreting differences.") }
        if baseline.volumeName != current.volumeName { warnings.append("The reported volume name changed. Verify the chosen folder and volume.") }
        return warnings
    }
}
