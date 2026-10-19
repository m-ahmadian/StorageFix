import Foundation

/// Measures and empties allow-listed cache folders. Never follows symbolic links and never removes the folder itself.
struct CacheFileSystem: Sendable {
    let home: URL
    var now: @Sendable () -> Date = { Date() }
    /// Items changed this recently are never offered as leftovers; the app may be mid-reinstall or update.
    static let leftoverQuietDays = 7
    private static let sizeKeys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    /// Existing, non-symlinked folders a scope covers; a folder reached through a link is skipped entirely.
    func targets(for scope: CacheCategoryDefinition.Scope) -> [URL] {
        let paths: [String]
        switch scope {
        case .contents(let relative): paths = relative
        case .childrenExcluding(let relative, _, _), .files(let relative, _, _): paths = [relative]
        case .orphans(let relative): paths = relative
        }
        return paths.map { home.appending(path: $0, directoryHint: .isDirectory) }.filter(isSafeFolder)
    }

    /// Entries that cleaning would remove for this scope. Leftovers are only listed when the installed apps are known.
    func removableEntries(for scope: CacheCategoryDefinition.Scope, installed: InstalledApplicationIndex? = nil) -> [URL] {
        targets(for: scope).flatMap { folder -> [URL] in
            let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey, .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey]
            let children = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
            switch scope {
            case .contents: return children
            case .childrenExcluding(_, let names, let prefixes):
                return children.filter { child in
                    let name = child.lastPathComponent
                    return !names.contains(name) && !prefixes.contains { name.hasPrefix($0) }
                }
            case .files(_, let extensions, let days):
                return children.filter { child in
                    guard extensions.contains(child.pathExtension.lowercased()),
                          let values = try? child.resourceValues(forKeys: Set(keys)),
                          values.isSymbolicLink != true, values.isRegularFile == true,
                          let added = values.addedToDirectoryDate ?? values.creationDate else { return false }
                    return isOlder(added, thanDays: days)
                }
            case .orphans:
                guard let installed else { return [] }
                return children.filter { child in
                    guard let id = InstalledApplicationIndex.bundleID(forItemNamed: child.lastPathComponent), !installed.contains(id),
                          let values = try? child.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { return false }
                    return isOlder(values.contentModificationDate ?? .distantPast, thanDays: Self.leftoverQuietDays)
                }
            }
        }
    }

    private func isOlder(_ date: Date, thanDays days: Int) -> Bool {
        now().timeIntervalSince(date) > TimeInterval(days) * 86_400
    }

    func allocatedBytes(of entries: [URL]) throws -> Int64 {
        var total: Int64 = 0
        for entry in entries {
            try Task.checkCancellation()
            total = total.addingReportingOverflow(try allocatedBytes(of: entry)).partialValue
        }
        return total
    }

    /// Removes (or moves to the Trash) each entry after confirming it sits directly inside a safe target folder.
    /// Returns failed entries.
    func remove(_ entries: [URL], within targets: [URL], toTrash: Bool = false) throws -> [URL] {
        let allowed = Set(targets.map { $0.standardizedFileURL.path })
        var failed: [URL] = []
        for entry in entries {
            try Task.checkCancellation()
            guard allowed.contains(entry.deletingLastPathComponent().standardizedFileURL.path) else { failed.append(entry); continue }
            do {
                if toTrash { try FileManager.default.trashItem(at: entry, resultingItemURL: nil) }
                else { try FileManager.default.removeItem(at: entry) }
            } catch { failed.append(entry) }
        }
        return failed
    }

    func availableBytes() -> Int64? {
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? values?.volumeAvailableCapacity.map(Int64.init)
    }

    private func allocatedBytes(of entry: URL) throws -> Int64 {
        let values = try? entry.resourceValues(forKeys: Set(Self.sizeKeys))
        if values?.isSymbolicLink == true { return 0 }
        if values?.isRegularFile == true { return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0) }
        guard let enumerator = FileManager.default.enumerator(at: entry, includingPropertiesForKeys: Self.sizeKeys,
            options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            try Task.checkCancellation()
            guard let item = try? file.resourceValues(forKeys: Set(Self.sizeKeys)), item.isSymbolicLink != true,
                  item.isRegularFile == true else { continue }
            total += Int64(item.totalFileAllocatedSize ?? item.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// The folder and every folder between it and Home must exist and must not be a symbolic link.
    private func isSafeFolder(_ folder: URL) -> Bool {
        let homePath = home.standardizedFileURL.path
        var current = folder.standardizedFileURL
        guard current.path.hasPrefix(homePath + "/") else { return false }
        while current.path != homePath {
            guard let values = try? current.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
                  values.isSymbolicLink != true, values.isDirectory == true else { return false }
            current = current.deletingLastPathComponent().standardizedFileURL
        }
        return true
    }
}
