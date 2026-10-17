import Foundation

/// Reusable presentation value, independent of SwiftUI and of any feature module.
public struct InventorySummary: Equatable, Sendable {
    public let title: String
    public let sizeDetail: String
    public let volumeDetail: String
    public let reasonDetails: [String]
    public let examples: [String]

    public init(scan: InventoryScan) {
        let status = scan.wasCancelled ? "Cancelled · partial inventory" : (!scan.coverageAvailable
            ? "Inventory returned · coverage unavailable" : (scan.coverage.hasReadErrors ? "Partial inventory" : "Inventory finished"))
        title = "\(status) · \(scan.files.count) files"
        sizeDetail = "\(Self.size(scan.logicalBytes)) logical · \(Self.size(scan.knownAllocatedBytes)) known allocated · \(scan.unknownAllocatedCount) allocated sizes unknown. APFS sharing can affect physical usage; these are not reclaimable-space estimates."
        if let volume = scan.volume {
            let available = volume.availableBytes.map(Self.size) ?? "Unknown"
            let capacity = volume.capacityBytes.map(Self.size) ?? "unknown"
            let access = volume.isReadOnly.map { $0 ? "Read-only" : "Writable volume" } ?? "Write access unknown"
            volumeDetail = "\(volume.name ?? "Selected volume") · \(available) available / \(capacity) capacity · \(access)"
        } else { volumeDetail = "Volume capacity and write access unavailable." }
        reasonDetails = scan.coverageAvailable ? InventoryIssueReason.allCases.compactMap { reason in
            guard let count = scan.coverage.counts[reason], count > 0 else { return nil }
            return "\(Self.label(reason)): \(count) observed entries"
        } : ["Detailed coverage unavailable for this inventory source."]
        examples = ["\(scan.files.filter { $0.mayShareContent == true }.count) files may share APFS blocks; \(scan.files.filter { $0.mayShareContent == nil }.count) sharing flags unknown. Shared block totals are unavailable."] + scan.coverage.examples.map { "\(Self.label($0.reason)): \($0.path)" }
    }

    private static func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    private static func label(_ reason: InventoryIssueReason) -> String {
        switch reason {
        case .inaccessible: "Inaccessible"
        case .disappeared: "Disappeared during scan"
        case .changed: "Changed during scan"
        case .hidden: "Hidden entries excluded"
        case .package: "Packages excluded"
        case .symbolicLink: "Symbolic links excluded"
        case .cloudPlaceholder: "Cloud placeholders excluded"
        case .sharedLink: "Additional hard links counted once"
        case .unknownIdentity: "Shared identity unavailable"
        case .unknownSize: "Logical size unavailable"
        case .unsupported: "Unsupported or outside scope"
        }
    }
}
