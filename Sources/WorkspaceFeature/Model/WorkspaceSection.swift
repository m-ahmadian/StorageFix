public enum WorkspaceSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case comparison = "Scan Comparison"
    case queue = "Review Queue"
    case overview = "Quick Review", cleanup = "Cleanup", map = "Storage Map", duplicates = "Duplicates", photos = "Similar Photos", files = "Large & Old Files", apps = "Applications", safety = "Safety Check"
    public var id: String { rawValue }
    var symbol: String {
        switch self { case .comparison: "arrow.left.arrow.right"; case .queue: "tray.full"; case .overview: "sparkles"; case .cleanup: "leaf"; case .map: "chart.pie"; case .duplicates: "doc.on.doc"; case .photos: "photo.on.rectangle.angled"; case .files: "folder"; case .apps: "square.stack.3d.up"; case .safety: "checkmark.shield" }
    }
}
