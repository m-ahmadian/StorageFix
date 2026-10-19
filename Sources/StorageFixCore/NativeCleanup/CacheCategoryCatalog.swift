import Foundation

/// What a native cleanup category removes, relative to the user's Home folder.
public struct CacheCategoryDefinition: Equatable, Sendable {
    public enum Scope: Equatable, Sendable {
        /// Remove everything inside each folder; the folders themselves stay.
        case contents([String])
        /// Remove the children of one folder except the named entries and prefixes.
        case childrenExcluding(String, names: Set<String>, prefixes: [String])
        /// Top-level regular files in one folder with one of these extensions, added more than `olderThanDays` ago.
        case files(String, extensions: Set<String>, olderThanDays: Int)
        /// Bundle-ID named items in these folders that belong to no installed application.
        case orphans([String])
    }
    public let id: String
    public let name: String
    public let displayPath: String
    public let scope: Scope
    public let safeDefault: Bool
    public let warning: String
    /// Cleaning is blocked while an app whose bundle ID starts with one of these is running.
    public let blockingBundlePrefixes: [String]
    /// Moved to the Trash instead of deleted, for anything that is not a rebuildable cache.
    public var movesToTrash = false
}

/// Allow-listed, rebuildable caches. Nothing outside these folders is ever removed.
public enum CacheCategoryCatalog {
    static let xcode = ["com.apple.dt.Xcode"]

    /// Everything the sandboxed edition may clean: rebuildable caches plus Trash-only installers and leftovers.
    public static let standard: [CacheCategoryDefinition] = caches + developer + clutter
    /// The direct edition adds simulator contents, which the sandbox cannot reach safely.
    public static let direct: [CacheCategoryDefinition] = standard + directOnly

    static let caches: [CacheCategoryDefinition] = [
        .init(id: "xcode-derived-data", name: "Xcode Derived Data", displayPath: "~/Library/Developer/Xcode/DerivedData",
              scope: .contents(["Library/Developer/Xcode/DerivedData"]), safeDefault: true,
              warning: "Xcode rebuilds projects the next time they open.", blockingBundlePrefixes: xcode),
        .init(id: "xcode-doc-cache", name: "Xcode Documentation Cache", displayPath: "~/Library/Developer/Xcode/DocumentationCache",
              scope: .contents(["Library/Developer/Xcode/DocumentationCache"]), safeDefault: true,
              warning: "Xcode documentation will be downloaded again when needed.", blockingBundlePrefixes: xcode),
        .init(id: "swiftpm-cache", name: "Swift Package Manager Cache", displayPath: "~/Library/Caches/org.swift.swiftpm",
              scope: .contents(["Library/Caches/org.swift.swiftpm"]), safeDefault: true,
              warning: "", blockingBundlePrefixes: []),
        .init(id: "npm-cache", name: "npm and npx Cache", displayPath: "~/.npm",
              scope: .contents([".npm"]), safeDefault: true,
              warning: "npm packages and npx tools will be downloaded again when needed.", blockingBundlePrefixes: []),
        .init(id: "node-gyp-cache", name: "node-gyp Cache", displayPath: "~/Library/Caches/node-gyp",
              scope: .contents(["Library/Caches/node-gyp"]), safeDefault: true,
              warning: "Node headers will be downloaded again when native packages build.", blockingBundlePrefixes: []),
        .init(id: "google-cache", name: "Google Application Cache", displayPath: "~/Library/Caches/Google",
              scope: .contents(["Library/Caches/Google"]), safeDefault: true,
              warning: "Cached web content will be recreated.", blockingBundlePrefixes: ["com.google."]),
        .init(id: "adobe-cache", name: "Adobe Cache", displayPath: "~/Library/Caches/Adobe",
              scope: .contents(["Library/Caches/Adobe"]), safeDefault: true,
              warning: "Cached content will be recreated.", blockingBundlePrefixes: ["com.adobe."]),
        .init(id: "claude-cache", name: "Claude Desktop Cache", displayPath: "~/Library/Application Support/Claude",
              scope: .contents(["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache"]
                  .map { "Library/Application Support/Claude/\($0)" }), safeDefault: true,
              warning: "Cached desktop content will be recreated.", blockingBundlePrefixes: ["com.anthropic.claude"]),
        .init(id: "app-logs", name: "Application Logs", displayPath: "~/Library/Logs",
              scope: .contents(["Library/Logs"]), safeDefault: true,
              warning: "Diagnostic logs will be permanently removed.", blockingBundlePrefixes: []),
        .init(id: "codex-runtime-cache", name: "Codex Runtime Cache", displayPath: "~/.cache/codex-runtimes",
              scope: .contents([".cache/codex-runtimes"]), safeDefault: false,
              warning: "Runtime dependencies will be downloaded again when needed.", blockingBundlePrefixes: ["com.openai.codex"]),
        .init(id: "ios-device-support", name: "iOS Device Support", displayPath: "~/Library/Developer/Xcode/iOS DeviceSupport",
              scope: .contents(["Library/Developer/Xcode/iOS DeviceSupport"]), safeDefault: false,
              warning: "Debug support files for connected devices will be downloaded again when needed.", blockingBundlePrefixes: xcode),
        .init(id: "user-cache-files", name: "Other Application Caches", displayPath: "~/Library/Caches",
              scope: .childrenExcluding("Library/Caches", names: ["org.swift.swiftpm", "Google", "Adobe", "node-gyp"],
                                        prefixes: ["com.apple.", "com.mehrdad.storagefix"]),
              safeDefault: false,
              warning: "Optional: quit applications first. Apps rebuild their caches and may need to sign in again. Apple system caches are skipped.",
              blockingBundlePrefixes: [])
    ]
}
