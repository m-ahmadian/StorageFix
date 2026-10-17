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
