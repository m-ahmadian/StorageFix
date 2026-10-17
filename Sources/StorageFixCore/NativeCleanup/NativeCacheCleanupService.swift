import Foundation

/// Swift-only cache cleanup for the sandboxed edition. Works only inside the person's granted Home folder, only on
/// allow-listed cache folders, after an explicit review. Selected cache contents are permanently deleted (owner decision
/// October 17, 2026); reclaimed space is the measured change in volume free space.
public actor NativeCacheCleanupService: CleanupServiceProtocol {
    public nonisolated let requiredFolder: URL?
    private let fileSystem: CacheFileSystem
    private let catalog: [CacheCategoryDefinition]
    private let runningApplications: any RunningApplicationsProviding
    private var granted: Bool

    /// - Parameter requiresGrant: true in the sandbox, where Home must be chosen in an open panel first.
    public init(home: URL, requiresGrant: Bool, runningApplications: any RunningApplicationsProviding = WorkspaceRunningApplications(),
                catalog: [CacheCategoryDefinition] = CacheCategoryCatalog.standard) {
        let home = home.standardizedFileURL
        requiredFolder = requiresGrant ? home : nil
        fileSystem = CacheFileSystem(home: home)
        self.catalog = catalog; self.runningApplications = runningApplications; granted = !requiresGrant
    }

    public var hasAccess: Bool { granted }

    public func grantAccess(to folder: URL) throws {
        guard folder.resolvingSymlinksInPath().standardizedFileURL.path == fileSystem.home.resolvingSymlinksInPath().path else {
            throw NativeCleanupError.wrongFolder(fileSystem.home.path)
        }
        granted = true
    }

    public func scan() async throws -> CleanupReport {
        try requireAccess()
        let free = fileSystem.availableBytes() ?? 0
        var categories: [CleanupCategory] = []
        for definition in catalog {
            try Task.checkCancellation()
            let bytes = try fileSystem.allocatedBytes(of: fileSystem.removableEntries(for: definition.scope))
            categories.append(category(definition, before: bytes, after: bytes, status: .scanned, message: ""))
        }
        return CleanupReport(mode: "scan", freeBytesBefore: free, freeBytesAfter: free, freeBytesReclaimed: 0, categories: categories)
    }

    public func clean(categoryIDs: Set<String>) async throws -> CleanupReport {
        try requireAccess()
        let running = await runningApplications.runningBundleIdentifiers()
        let freeBefore = fileSystem.availableBytes() ?? 0
        var categories: [CleanupCategory] = []
        for definition in catalog {
            try Task.checkCancellation()
            categories.append(try clean(definition, selected: categoryIDs.contains(definition.id), running: running))
        }
        let freeAfter = fileSystem.availableBytes() ?? freeBefore
        return CleanupReport(mode: "clean", freeBytesBefore: freeBefore, freeBytesAfter: freeAfter,
                             freeBytesReclaimed: max(0, freeAfter - freeBefore), categories: categories)
    }

    private func clean(_ definition: CacheCategoryDefinition, selected: Bool, running: Set<String>) throws -> CleanupCategory {
        let entries = fileSystem.removableEntries(for: definition.scope)
        let before = try fileSystem.allocatedBytes(of: entries)
        guard selected else { return category(definition, before: before, after: before, status: .scanned, message: "") }
        if let app = running.first(where: { id in definition.blockingBundlePrefixes.contains { id.hasPrefix($0) } }) {
            return category(definition, before: before, after: before, status: .blocked, message: "Quit \(app) and try again.")
        }
        let failed = try fileSystem.remove(entries, within: fileSystem.targets(for: definition.scope))
        let after = try fileSystem.allocatedBytes(of: fileSystem.removableEntries(for: definition.scope))
        let status: CleanupStatus = failed.isEmpty || after < before ? .cleaned : .failed
        let message = failed.isEmpty ? "" : "\(failed.count) \(failed.count == 1 ? "item" : "items") could not be removed (in use or protected by macOS)."
        return category(definition, before: before, after: after, status: status, message: message)
    }

    private func category(_ definition: CacheCategoryDefinition, before: Int64, after: Int64,
                          status: CleanupStatus, message: String) -> CleanupCategory {
        CleanupCategory(id: definition.id, name: definition.name, path: definition.displayPath, safeDefault: definition.safeDefault,
                        warning: definition.warning, bytesBefore: before, bytesAfter: after,
                        bytesReclaimed: max(0, before - after), status: status, message: message)
    }

    private func requireAccess() throws {
        guard granted else { throw NativeCleanupError.accessRequired(fileSystem.home.path) }
    }
}
