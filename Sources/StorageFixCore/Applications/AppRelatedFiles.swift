import Foundation

/// A settings, cache or support item that belongs to an installed app.
public struct RelatedFile: Identifiable, Equatable, Sendable {
    public let path: String
    public let bytes: Int64
    /// The Library folder it lives in, for example "Preferences".
    public let location: String
    /// Matched by the app's name rather than its bundle identifier; never preselected.
    public let matchedByName: Bool
    public var id: String { path }
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public init(path: String, bytes: Int64, location: String, matchedByName: Bool) {
        self.path = path; self.bytes = bytes; self.location = location; self.matchedByName = matchedByName
    }
}

public enum RelatedFilesError: LocalizedError, Equatable, Sendable {
    case accessRequired
    public var errorDescription: String? { "Allow access to your Home folder (Scan My Mac or Cleanup) so StorageFix can find this app's settings and caches." }
}

public protocol AppRelatedFilesProviding: Sendable {
    /// Throws `RelatedFilesError.accessRequired` while the Library cannot be read yet.
    func relatedFiles(bundleID: String, appName: String) async throws -> [RelatedFile]
    /// Moves found items to the Trash. Returns the paths that could not be moved.
    func moveToTrash(_ files: [RelatedFile]) async -> [String]
}

/// Finds an app's leftovers in the person's Library the way dedicated uninstallers do: by bundle identifier
/// (exact, or followed by a dot) and, flagged separately, by exact app name. Apple apps are never offered.
public actor AppRelatedFilesFinder: AppRelatedFilesProviding {
    static let identifierFolders = ["Application Support", "Caches", "Logs", "HTTPStorages", "WebKit", "Saved Application State",
                                    "Preferences", "Preferences/ByHost", "Cookies", "LaunchAgents"]
    static let containerFolders = ["Containers", "Application Scripts"]
    static let nameFolders = ["Application Support", "Caches", "Logs"]
    private let library: URL
    private let folders: [String]
    private var found: Set<String> = []
    private let hasAccess: @Sendable () async -> Bool

    /// - Parameters:
    ///   - includesContainers: only outside the sandbox, where other apps' containers are reachable.
    ///   - hasAccess: whether the Home folder may be read yet (the sandboxed edition needs the one-time Allow).
    public init(home: URL, includesContainers: Bool, hasAccess: @escaping @Sendable () async -> Bool = { true }) {
        library = home.appending(path: "Library", directoryHint: .isDirectory).standardizedFileURL
        folders = Self.identifierFolders + (includesContainers ? Self.containerFolders : [])
        self.hasAccess = hasAccess
    }

    public func relatedFiles(bundleID: String, appName: String) async throws -> [RelatedFile] {
        guard await hasAccess() else { throw RelatedFilesError.accessRequired }
        let id = bundleID.lowercased(), name = appName.lowercased()
        guard id.split(separator: ".").count >= 2, !id.hasPrefix("com.apple."), !id.hasPrefix("com.mehrdad.storagefix") else { return [] }
        let nameIsDistinct = name.count >= 4 && !Self.genericNames.contains(name)
        var results: [RelatedFile] = []
        for folder in folders {
            let base = library.appending(path: folder, directoryHint: .isDirectory)
            let children = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? []
            for child in children {
                let entry = child.lastPathComponent.lowercased()
                let byID = entry == id || entry.hasPrefix(id + ".")
                let byName = !byID && nameIsDistinct && Self.nameFolders.contains(folder) && entry == name
                guard byID || byName, (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true else { continue }
                results.append(RelatedFile(path: child.path, bytes: Self.allocatedBytes(child), location: folder, matchedByName: byName))
            }
        }
        found = Set(results.map(\.path))
        return results.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
    }

    public func moveToTrash(_ files: [RelatedFile]) async -> [String] {
        var failed: [String] = []
        for file in files {
            let url = URL(fileURLWithPath: file.path).standardizedFileURL
            guard found.contains(file.path), url.path.hasPrefix(library.path + "/") else { failed.append(file.path); continue }
            do { try FileManager.default.trashItem(at: url, resultingItemURL: nil); found.remove(file.path) } catch { failed.append(file.path) }
        }
        return failed
    }

    /// Names so common that a folder called this could belong to anything.
    static let genericNames: Set<String> = ["notes", "music", "photos", "mail", "calendar", "files", "data", "cache", "logs", "settings",
                                            "preview", "books", "news", "home", "maps", "clock", "safari", "terminal", "help"]

    static func allocatedBytes(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [],
                                                              errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: keys), values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
