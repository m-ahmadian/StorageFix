import Foundation

/// Immutable metadata projection. Building this index performs no filesystem calls.
/// Every regular-file path has one leaf; each directory stores only immediate children.
public struct StorageMapIndex: Equatable, Sendable {
    private let children: [String: [StorageMapItem]]
    public let rootPath: String
    public init(files: [DuplicateFile], root: URL) throws {
        try Task.checkCancellation()
        rootPath = root.standardizedFileURL.path
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        var groups: [String: [String: Aggregate]] = [:]
        for file in files {
            try Task.checkCancellation()
            guard file.path.hasPrefix(prefix) else { continue }
            let parts = file.path.dropFirst(prefix.count).split(separator: "/", omittingEmptySubsequences: false)
            guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { continue }
            var parent = rootPath
            for (offset, part) in parts.enumerated() {
                let folder = offset < parts.count - 1
                let path = folder ? (parent == "/" ? "/" : parent + "/") + part : file.path
                groups[parent, default: [:]][path, default: Aggregate()].include(file.bytes, isFolder: folder)
                parent = path
            }
        }
        var result: [String: [StorageMapItem]] = [:]
        for (parent, entries) in groups {
            try Task.checkCancellation()
            result[parent] = entries.map { path, value in
                StorageMapItem(path: path, bytes: value.bytes, fileCount: value.count, isFolder: value.isFolder)
            }.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
        }
        children = result
    }
    public func items(at folder: URL) -> [StorageMapItem] { children[folder.path] ?? [] }
}

private struct Aggregate {
    var bytes: Int64 = 0
    var count = 0
    var isFolder = false
    mutating func include(_ bytes: Int64, isFolder: Bool) {
        self.bytes += bytes; count += 1; self.isFolder = self.isFolder || isFolder
    }
}
