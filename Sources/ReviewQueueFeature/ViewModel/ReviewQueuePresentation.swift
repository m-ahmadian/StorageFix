import Foundation
import StorageFixCore

extension ReviewQueueViewModel {
    var emptyTitle: String { snapshot.lastRun == nil ? "Choose files first" : "The queue is empty" }
    var emptyDescription: String {
        snapshot.lastRun == nil ? "Add selected files from Storage Map, Large & Old Files, or Duplicates. Nothing is selected automatically."
            : "Review the operation results below. Add new files from a fresh scan whenever you need another review."
    }
    var countDescription: String { "\(snapshot.items.count) files · \(size(logicalBytes)) logical size" }
    var runDescription: String? {
        guard let run = snapshot.lastRun else { return nil }
        return "\(run.movedCount) of \(run.outcomes.count) files moved to Trash. Unmoved entries require a fresh scan and review. Trash is never emptied here."
    }
    var freeSpaceDescription: String? {
        guard let measurement = snapshot.lastRun?.freeSpace else { return nil }
        guard measurement.isMeasured, let change = measurement.changeBytes, let after = measurement.afterBytes else {
            return "Free space not measured. \(measurement.unavailableReason ?? "") Logical sizes moved to Trash are not recovered space."
        }
        let direction = change >= 0 ? "increased by \(size(change))" : "decreased by \(size(-change))"
        return "Volume free space \(direction) since this operation began (now \(size(after)), measured \(measurement.measuredAt.formatted(date: .omitted, time: .standard))). Other apps and local snapshots also change this, and files in Trash usually keep using space until you empty Trash in Finder."
    }
    var progressDescription: String { "Checked or attempted \(snapshot.completedCount) of \(snapshot.items.count) items. Validating file versions and kept copies." }
    func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    func origins(_ item: ReviewQueueItem) -> String { item.origins.map(\.rawValue).sorted().joined(separator: " · ") }
    func status(_ outcome: ReviewQueueOutcome) -> String {
        switch outcome.status {
        case .moved: "Moved to Trash"
        case .blocked: "Blocked before changes"
        case .failed: "Needs attention"
        case .cancelled: "Cancelled"
        }
    }
}
