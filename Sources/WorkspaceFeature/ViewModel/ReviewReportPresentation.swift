import Foundation

public extension ReviewReport {
    var needsAttention: Bool { areas.contains { $0.error != nil } }
    var heading: String { needsAttention ? "Review needs attention" : "Review complete" }
    var explanation: String {
        "Snapshot from \(date.formatted(date: .abbreviated, time: .shortened)). Scans changed no files. Figures overlap and are not a total of reclaimable space."
    }
    var text: String {
        let header = ["StorageFix review report", explanation, "Folder: \(folder)"]
        let disk = availableBytes.map { "Disk available at review: \(Self.size($0))" }
        let details = areas.map {
            "\($0.section.rawValue)\nScope: \($0.scope)\n\($0.summary)" + ($0.error.map { "\nAttention: \($0)" } ?? "")
        }
        return (header + [disk].compactMap { $0 } + details + [
            "Folder sizes are logical file sizes. Duplicate bytes describe extra copies. Applications are bundle sizes; caches are measured separately.",
            "Results can change after scanning. Trash actions do not free disk space until Trash is emptied."
        ]).joined(separator: "\n\n")
    }
    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

public extension ReviewAreaResult {
    var summary: String {
        guard error == nil, let itemCount, let bytes else { return "Scan needs attention" }
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        switch section {
        case .files: return "\(itemCount) \(itemCount == 1 ? "file" : "files") inventoried · \(size)"
        case .duplicates: return "\(itemCount) extra \(itemCount == 1 ? "copy" : "copies") · \(size)"
        case .apps: return "\(itemCount) application \(itemCount == 1 ? "bundle" : "bundles") · \(size)"
        case .cleanup: return "\(itemCount) cache \(itemCount == 1 ? "category" : "categories") · \(size)"
        default: return "\(itemCount) items · \(size)"
        }
    }
}
