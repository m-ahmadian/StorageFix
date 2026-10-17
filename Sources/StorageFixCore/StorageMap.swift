import Foundation

public struct StorageMapItem: Identifiable, Equatable, Sendable {
    public let path: String
    public let bytes: Int64
    public let fileCount: Int
    public let isFolder: Bool
    public var id: String { path }
    public var name: String { (path as NSString).lastPathComponent }
}

public enum StorageMap {
    public static let primaryChartItemCount = 5

    /// The remainder keeps segment proportions relative to the whole inventory.
    public static func chartSlices(items: [StorageMapItem]) -> [StorageMapSlice] {
        var slices = items.prefix(primaryChartItemCount).map {
            StorageMapSlice(id: .item($0.path), name: $0.name, bytes: $0.bytes, itemCount: 1)
        }
        let remainder = items.dropFirst(primaryChartItemCount)
        if !remainder.isEmpty {
            slices.append(StorageMapSlice(id: .remainder, name: "Other items",
                bytes: remainder.reduce(0) { $0 + $1.bytes }, itemCount: remainder.count))
        }
        return slices
    }

    /// Groups a scanned inventory at the chosen level without rescanning on drill-down.
    public static func items(files: [DuplicateFile], at root: URL) -> [StorageMapItem] {
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var groups: [String: [DuplicateFile]] = [:]
        for file in files {
            let path = (file.path as NSString).standardizingPath
            guard path.hasPrefix(prefix), let name = path.dropFirst(prefix.count).split(separator: "/").first else { continue }
            groups[prefix + name, default: []].append(file)
        }
        return groups.map { path, files in
            StorageMapItem(path: path, bytes: files.reduce(0) { $0 + $1.bytes }, fileCount: files.count,
                isFolder: files.contains { ($0.path as NSString).standardizingPath != path })
        }.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
    }
}
