import Foundation

@MainActor public protocol FolderAccessSessionProtocol: AnyObject, Sendable {
    func retain(_ folder: URL)
    func close()
}

/// Owned by the app composition root, released when that session ends. No saved bookmarks.
@MainActor public final class FolderAccessSession: FolderAccessSessionProtocol {
    private var folders: [String: URL] = [:]
    public init() {}
    public func retain(_ folder: URL) {
        guard folders[folder.path] == nil else { return }
        if folder.startAccessingSecurityScopedResource() { folders[folder.path] = folder }
    }
    public func close() {
        for folder in folders.values { folder.stopAccessingSecurityScopedResource() }
        folders.removeAll()
    }
    deinit {
        for folder in folders.values { folder.stopAccessingSecurityScopedResource() }
    }
}
