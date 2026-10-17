import Foundation

/// Net observed logical-size change per top-level folder of a comparison. Describes metadata only, never recovered space.
public struct ScanFolderChange: Equatable, Identifiable, Sendable {
    /// Top-level folder relative to the scanned root; nil for files directly in the root.
    public let folder: String?
    public let byteChange: Int64
    public let changedPaths: Int
    public var id: String { folder ?? "" }
}

extension ScanComparison {
    /// Folders ordered by the size of their net change, largest first. Folders whose changes cancel out are kept
    /// (they still changed) and sort by path count.
    public func folderChanges(limit: Int = 5) -> [ScanFolderChange] {
        var totals: [String?: (bytes: Int64, count: Int)] = [:]
        for item in items {
            let parts = item.path.split(separator: "/", maxSplits: 1)
            let folder = parts.count > 1 ? String(parts[0]) : nil
            let delta = (item.afterBytes ?? 0).subtractingReportingOverflow(item.beforeBytes ?? 0)
            let current = totals[folder] ?? (0, 0)
            let sum = current.bytes.addingReportingOverflow(delta.overflow ? 0 : delta.partialValue)
            totals[folder] = (sum.overflow ? current.bytes : sum.partialValue, current.count + 1)
        }
        return totals.map { ScanFolderChange(folder: $0.key, byteChange: $0.value.bytes, changedPaths: $0.value.count) }
            .sorted { left, right in
                let l = left.byteChange.magnitude, r = right.byteChange.magnitude
                if l != r { return l > r }
                if left.changedPaths != right.changedPaths { return left.changedPaths > right.changedPaths }
                return (left.folder ?? "") < (right.folder ?? "")
            }
            .prefix(max(0, limit)).map { $0 }
    }
}
