import Foundation

@MainActor public protocol FolderAccessSessionProtocol: AnyObject, Sendable {
    func retain(_ folder: URL)
    /// Keeps access to this folder across launches (security-scoped bookmark). Used only for the cleanup Home grant.
    func remember(_ folder: URL)
    func close()
}

public extension FolderAccessSessionProtocol {
    func remember(_ folder: URL) { retain(folder) }
}

/// Owned by the app composition root. Review folders last for the session; only folders explicitly remembered
/// (the cache-cleanup Home grant) are stored as bookmarks so the person is not asked again.
@MainActor public final class FolderAccessSession: FolderAccessSessionProtocol {
    static let rememberedKey = "storagefix.rememberedFolders.v1"
    private var folders: [String: URL] = [:]
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func retain(_ folder: URL) {
        guard folders[folder.path] == nil else { return }
        if folder.startAccessingSecurityScopedResource() { folders[folder.path] = folder }
    }

    public func remember(_ folder: URL) {
        retain(folder)
        guard let data = try? folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var stored = defaults.dictionary(forKey: Self.rememberedKey) as? [String: Data] ?? [:]
        stored[folder.standardizedFileURL.path] = data
        defaults.set(stored, forKey: Self.rememberedKey)
    }

    /// Restores remembered folders at launch and returns those whose access could be resumed.
    public func restoreRemembered() -> [URL] {
        guard var stored = defaults.dictionary(forKey: Self.rememberedKey) as? [String: Data] else { return [] }
        var restored: [URL] = []
        for (path, data) in stored {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
                                     bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() else {
                stored[path] = nil; continue
            }
            folders[url.path] = url
            restored.append(url)
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                stored[path] = fresh
            }
        }
        defaults.set(stored, forKey: Self.rememberedKey)
        return restored
    }

    /// Forgets every remembered folder; access ends now and the app asks again next time.
    public func forgetRemembered() {
        defaults.removeObject(forKey: Self.rememberedKey)
        close()
    }

    public func close() {
        for folder in folders.values { folder.stopAccessingSecurityScopedResource() }
        folders.removeAll()
    }

    deinit {
        for folder in folders.values { folder.stopAccessingSecurityScopedResource() }
    }
}
