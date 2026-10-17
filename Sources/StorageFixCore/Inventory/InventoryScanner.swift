import Foundation

/// A synchronous metadata worker with bounded progress and bounded diagnostic samples.
public struct InventoryScanner: Sendable {
    public static let progressInterval: Duration = .milliseconds(100)
    private let source: any InventoryMetadataSource
    public init(source: any InventoryMetadataSource) { self.source = source }

    public func scan(root: URL, options: InventoryOptions, sessionID: UUID,
                     progress: @Sendable (InventoryProgress) -> Void) throws -> InventoryScan {
        try Task.checkCancellation()
        var state = ScanState(root: root, options: options, sessionID: sessionID)
        progress(state.progress)
        var lastUpdate = ContinuousClock.now
        var cancelled = false
        do {
            try source.walk(root: root, visit: { item in
                try Task.checkCancellation()
                let descend = state.visit(item)
                if lastUpdate.duration(to: .now) >= Self.progressInterval {
                    progress(state.progress); lastUpdate = .now
                }
                return descend
            }, issue: { state.coverage.record($0) })
        } catch is CancellationError { cancelled = true }
        progress(state.progress)
        return InventoryScan(sessionID: sessionID, root: root, options: options,
            files: state.files.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes },
            coverage: state.coverage, wasCancelled: cancelled || Task.isCancelled, volume: source.volume(at: root))
    }
}

private struct ScanState {
    let root: URL
    let options: InventoryOptions
    let sessionID: UUID
    var visited = 0
    var files: [DuplicateFile] = []
    var coverage = InventoryCoverage()
    var identities: Set<String> = []
    var paths: Set<String> = []
    var progress: InventoryProgress { InventoryProgress(sessionID: sessionID, visitedCount: visited, fileCount: files.count) }

    mutating func visit(_ item: InventoryMetadata) -> Bool {
        visited += 1
        let prefix = root.standardizedFileURL.path == "/" ? "/" : root.standardizedFileURL.path + "/"
        guard (item.path.hasPrefix(prefix) || item.isDirectory && item.path == root.standardizedFileURL.path),
              URL(fileURLWithPath: item.path).standardizedFileURL.path == item.path,
              paths.insert(item.path).inserted else {
            return exclude(item, .unsupported)
        }
        if item.isSymbolicLink { return exclude(item, .symbolicLink) }
        if item.isHidden && !options.includesHiddenFiles { return exclude(item, .hidden) }
        if item.isPackage && !options.includesPackageContents { return exclude(item, .package) }
        if item.isCloudPlaceholder { return exclude(item, .cloudPlaceholder) }
        if item.isDirectory { return true }
        guard item.isRegularFile else { return exclude(item, .unsupported) }
        guard let bytes = item.bytes, bytes >= 0 else { return exclude(item, .unknownSize) }
        if item.linkCount > 1 && item.identity == nil { return exclude(item, .unknownIdentity) }
        if let identity = item.identity, !identities.insert(identity).inserted { return exclude(item, .sharedLink) }
        files.append(DuplicateFile(path: item.path, bytes: bytes, modifiedAt: item.modifiedAt,
            fileIdentity: item.identity, allocatedBytes: item.allocatedBytes.flatMap { $0 >= 0 ? $0 : nil },
            isSharedLink: item.linkCount > 1, mayShareContent: item.mayShareContent))
        return false
    }

    private mutating func exclude(_ item: InventoryMetadata, _ reason: InventoryIssueReason) -> Bool {
        coverage.record(InventoryIssue(path: item.path, reason: reason))
        return false
    }
}
