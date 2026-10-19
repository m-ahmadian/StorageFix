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
        CleanupGroup(id: "developer-tools", title: "Developer Tools", categoryIDs: [
            "xcode-derived-data", "xcodebuildmcp-cache", "xcode-doc-cache", "simulator-caches", "xcode-previews"
        ], isExpandedByDefault: true),
        CleanupGroup(id: "package-caches", title: "Package Caches", categoryIDs: [
            "swiftpm-cache", "npm-cache", "node-gyp-cache", "gradle-cache", "cargo-cache", "bun-cache", "maven-repository", "cocoapods-repos"
        ], isExpandedByDefault: true),
        CleanupGroup(id: "application-caches", title: "Application Caches", categoryIDs: [
            "google-cache", "claude-cache", "adobe-cache", "adobe-media-cache", "codex-runtime-cache", "user-cache-files"
        ], isExpandedByDefault: true),
        CleanupGroup(id: "logs", title: "Logs", categoryIDs: ["app-logs"], isExpandedByDefault: true),
        CleanupGroup(id: "downloads", title: "Installers and Downloads", categoryIDs: [
            "old-installers", "ios-software-updates"
        ], isExpandedByDefault: true),
        CleanupGroup(id: "leftovers", title: "Deleted App Leftovers", categoryIDs: ["app-leftovers"], isExpandedByDefault: true),
        CleanupGroup(id: "ai-models", title: "AI Models", categoryIDs: [
            "ollama-models", "huggingface-cache", "lmstudio-models"
        ], isExpandedByDefault: false),
        CleanupGroup(id: "advanced", title: "Advanced", categoryIDs: [
            "simulator-contents", "ios-device-support", "xcode-archives"
        ], isExpandedByDefault: false)
    ]
}

public enum CleanupGroupSelectionState: Equatable, Sendable {
    case none
    case some
    case all
}
