import Foundation
import StorageFixCore

extension ScanComparisonViewModel {
    public var scopeDescription: String { currentScan?.root.path ?? "Scan a folder in Storage Map or Quick Review first." }
    public var baselineDescription: String {
        guard let baseline else { return "No baseline selected. Capture the current scan or open a snapshot you previously saved." }
        return "\(baseline.rootPath) · \(baseline.date.formatted()) · \(baseline.entries.count) \(baseline.entries.count == 1 ? "file" : "files") · \(size(baseline.logicalBytes)) logical size"
    }
    public var baselineWarning: String? {
        baseline?.hasIncompleteCoverage == true ? "This baseline has incomplete coverage. Differences may reflect permissions or skipped entries." : nil
    }
    public var comparisonSummary: String {
        guard let comparison else { return "Capture a baseline, rescan the same folder, then compare. No files are changed." }
        let sign = comparison.observedByteChange < 0 ? "−" : "+"
        return "Observed logical change: \(sign)\(size(abs(comparison.observedByteChange))) · \(comparison.items.count) changed paths · \(comparison.unchangedCount) unchanged"
    }
    public func size(_ bytes: Int64?) -> String { bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Not observed" }
    public var folderChanges: [ScanFolderChange] { comparison?.folderChanges() ?? [] }
    /// Largest absolute folder change, used to scale the bars.
    var largestFolderChange: Int64 { folderChanges.map(\.byteChange.magnitude).max().map { Int64(clamping: $0) } ?? 0 }
    func folderTitle(_ change: ScanFolderChange) -> String { change.folder ?? "Files in the scanned folder" }
    func signedSize(_ bytes: Int64) -> String {
        let sign = bytes < 0 ? "−" : (bytes > 0 ? "+" : "")
        return sign + ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes.magnitude), countStyle: .file)
    }
}
