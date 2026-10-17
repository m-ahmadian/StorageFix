import Foundation

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
    func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

extension WorkspaceViewModel {
    public var journey: ReviewJourney {
        ReviewJourney(ReviewJourney.Inputs(hasResults: latestReport != nil || files.hasScanned, hasExplored: hasExplored,
            queuedCount: reviewQueue?.snapshot.items.count ?? 0, lastRunDate: reviewQueue?.snapshot.lastRun?.date,
            lastReviewDate: lastReviewDate))
    }
    var journeyGuidance: String {
        guard let stage = journey.current else {
            return "Outcome checked with a fresh scan. Start another review whenever you like."
        }
        switch stage {
        case .choose:
            return files.needsFolder ? "Choose a folder, then run Quick Review. Scans only read metadata." : "Run Quick Review to measure this folder. Scans only read metadata."
        case .understand:
            return "Open Storage Map or the report to see where space goes. Nothing is selected for you."
        case .inspect:
            return "Inspect large files and duplicates, then add only the files you choose to the Review Queue."
        case .queue:
            let count = reviewQueue?.snapshot.items.count ?? 0
            return "\(count) \(count == 1 ? "file is" : "files are") waiting. Each is checked again before it moves to Trash."
        case .verify:
            return "Run Quick Review again and compare with your baseline. Space returns only after you empty Trash in Finder."
        }
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
