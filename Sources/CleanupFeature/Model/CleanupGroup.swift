public struct CleanupGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let categoryIDs: [String]
    public let isExpandedByDefault: Bool

    public init(
        id: String,
        title: String,
        categoryIDs: [String],
        isExpandedByDefault: Bool
    ) {
        self.id = id
        self.title = title
        self.categoryIDs = categoryIDs
        self.isExpandedByDefault = isExpandedByDefault
    }
}

public extension CleanupGroup {
    static let all: [CleanupGroup] = [
        CleanupGroup(
            id: "developer-tools",
            title: "Developer Tools",
            categoryIDs: [
                "xcode-derived-data",
                "xcodebuildmcp-cache",
                "xcode-doc-cache"
            ],
            isExpandedByDefault: true
        ),
        CleanupGroup(
            id: "package-caches",
            title: "Package Caches",
            categoryIDs: [
                "swiftpm-cache",
                "npm-cache",
                "node-gyp-cache"
            ],
            isExpandedByDefault: true
        ),
        CleanupGroup(
            id: "application-caches",
            title: "Application Caches",
            categoryIDs: [
                "google-cache",
                "claude-cache",
                "adobe-cache",
                "codex-runtime-cache",
                "user-cache-files"
            ],
            isExpandedByDefault: true
        ),
        CleanupGroup(
            id: "logs",
            title: "Logs",
            categoryIDs: ["app-logs"],
            isExpandedByDefault: true
        ),
        CleanupGroup(
            id: "advanced",
            title: "Advanced",
            categoryIDs: [
                "simulator-contents",
                "ios-device-support"
            ],
            isExpandedByDefault: false
        )
    ]
}

public enum CleanupGroupSelectionState: Equatable, Sendable {
    case none
    case some
    case all
}
