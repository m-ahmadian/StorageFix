import Foundation

public struct StorageSunburstSegment: Identifiable, Equatable, Sendable {
    public let slice: StorageMapSlice
    public let parentPath: String?
    public let startFraction: Double
    public let endFraction: Double
    public let colorIndex: Int
    public let isOuter: Bool
    public let extendsToEdge: Bool
    public var id: [StorageMapSlice.ID] { parentPath.map { [.item($0), slice.id] } ?? [slice.id] }
}

/// Two visible hierarchy levels; angles share one logical-byte denominator.
public enum StorageSunburst {
    public static func segments(files: [DuplicateFile], root: URL, items: [StorageMapItem]) -> [StorageSunburstSegment] {
        let prefix = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        let scoped = items.filter { $0.path.hasPrefix(prefix) }
        let slices = StorageMap.chartSlices(items: scoped)
        let total = Double(slices.reduce(0) { $0 + $1.bytes })
        guard total > 0 else { return [] }
        var result: [StorageSunburstSegment] = [], start = 0.0
        for (index, slice) in slices.enumerated() where slice.bytes > 0 {
            let end = start + Double(slice.bytes) / total
            let folder = scoped.first { .item($0.path) == slice.id && $0.isFolder }
            let children = folder.map { StorageMap.chartSlices(items: StorageMap.items(files: files, at: URL(fileURLWithPath: $0.path))) } ?? []
            result.append(StorageSunburstSegment(slice: slice, parentPath: nil, startFraction: start, endFraction: end,
                colorIndex: index, isOuter: false, extendsToEdge: children.isEmpty))
            if let folder {
                result += childSegments(children, parent: folder.path, start: start, total: total, color: index)
            }
            start = end
        }
        return result
    }
    private static func childSegments(_ children: [StorageMapSlice], parent: String, start: Double,
                                      total: Double, color: Int) -> [StorageSunburstSegment] {
        var result: [StorageSunburstSegment] = [], position = start
        for child in children where child.bytes > 0 {
            let end = position + Double(child.bytes) / total
            result.append(StorageSunburstSegment(slice: child, parentPath: parent, startFraction: position,
                endFraction: end, colorIndex: color, isOuter: true, extendsToEdge: true))
            position = end
        }
        return result
    }
}
