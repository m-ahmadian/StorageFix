import Foundation
import StorageFixCore

extension WorkspaceViewModel {
    func navigationTitle(_ section: WorkspaceSection) -> String {
        section == .queue ? "Review Queue (\(reviewQueue?.snapshot.items.count ?? 0))" : section.rawValue
    }
    private var collapsedActivityCount: Int { 3 }
    var hasMoreActivity: Bool { activity.count > collapsedActivityCount }
    func visibleActivity(expanded: Bool) -> [ActivityEntry] {
        expanded ? activity : Array(activity.prefix(collapsedActivityCount))
    }
    var fileInventoryDescription: String {
        guard files.hasScanned else { return "Find forgotten files" }
        return "\(files.files.count) \(files.files.count == 1 ? "file" : "files") inventoried"
    }
    var availablePercentage: String {
        guard let capacityBytes, let availableBytes, capacityBytes > 0 else { return "—" }
        return (Double(max(0, min(availableBytes, capacityBytes))) / Double(capacityBytes)).formatted(.percent.precision(.fractionLength(0)))
    }
    /// Share of the volume in use, 0...1; nil when capacity is unknown.
    var usedFraction: Double? {
        guard let capacityBytes, let availableBytes, capacityBytes > 0 else { return nil }
        return 1 - Double(max(0, min(availableBytes, capacityBytes))) / Double(capacityBytes)
    }
    var usedPercentage: String { usedFraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—" }
    var storagePressure: StoragePressure { StoragePressure(usedFraction: usedFraction) }
    func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

extension WorkspaceViewModel {
    public var journey: ReviewJourney {
        ReviewJourney(ReviewJourney.Inputs(hasResults: latestReport != nil || files.hasScanned, hasExplored: hasExplored,
            queuedCount: reviewQueue?.snapshot.items.count ?? 0, lastRunDate: pendingRun?.date,
            lastReviewDate: lastReviewDate))
    }
    /// The latest run still to verify: at least one file moved, and the person has not moved on from it.
    private var pendingRun: ReviewQueueRun? {
        guard let run = reviewQueue?.snapshot.lastRun, run.movedCount > 0, run.id != acknowledgedRunID else { return nil }
        return run
    }
    var journeyGuidance: String {
        guard let stage = journey.current else {
            return "Outcome checked with a fresh scan. Start another review whenever you like."
        }
        switch stage {
        case .choose:
            return files.needsFolder ? "Choose a folder, then run Quick Review. Scans only read metadata." : "Run Quick Review to measure this folder. Scans only read metadata."
        case .understand:
            return "Your review is ready. Open Storage Map or the report to see where space goes. Nothing is selected for you."
        case .inspect:
            return "Inspect large files and duplicates, then add only the files you choose to the Review Queue."
        case .queue:
            let count = reviewQueue?.snapshot.items.count ?? 0
            return "\(count) \(count == 1 ? "file is" : "files are") waiting. Each is checked again before it moves to Trash."
        case .verify:
            return "Run Quick Review again and compare with your baseline. Space returns only after you empty Trash in Finder."
        }
    }
    /// Shown on inspection screens while files wait in the queue.
    var queuePillSummary: String? {
        guard [.map, .duplicates, .files].contains(selectedSection), let queue = reviewQueue,
              !queue.isExecuting, !queue.snapshot.items.isEmpty else { return nil }
        let count = queue.snapshot.items.count
        return "\(count) \(count == 1 ? "file" : "files") · \(size(queue.logicalBytes))"
    }
    var journeyActionTitle: String? {
        switch journey.current {
        case .understand: "Open Storage Map"
        case .inspect: "Inspect Files"
        case .queue: "Open Review Queue"
        default: nil
        }
    }
}
