import Foundation

/// Developer, AI-model and clutter categories. Paths are relative to Home; only what is listed here is ever touched.
extension CacheCategoryCatalog {
    static let developer: [CacheCategoryDefinition] = [
        .init(id: "simulator-caches", name: "Simulator Caches", displayPath: "~/Library/Developer/CoreSimulator/Caches",
              scope: .contents(["Library/Developer/CoreSimulator/Caches"]), safeDefault: true,
              warning: "Simulators rebuild these caches on next launch. Your simulators and their apps stay.", blockingBundlePrefixes: xcode + ["com.apple.iphonesimulator"]),
        .init(id: "xcode-previews", name: "SwiftUI Previews", displayPath: "~/Library/Developer/Xcode/UserData/Previews",
              scope: .contents(["Library/Developer/Xcode/UserData/Previews"]), safeDefault: true,
              warning: "Xcode rebuilds previews when you open them.", blockingBundlePrefixes: xcode),
        .init(id: "gradle-cache", name: "Gradle Cache", displayPath: "~/.gradle/caches",
              scope: .contents([".gradle/caches"]), safeDefault: true,
              warning: "Android and Java builds download dependencies again.", blockingBundlePrefixes: ["com.google.android.studio"]),
        .init(id: "cargo-cache", name: "Rust Cargo Download Cache", displayPath: "~/.cargo/registry/cache",
              scope: .contents([".cargo/registry/cache"]), safeDefault: true,
              warning: "Crates download again when a project builds.", blockingBundlePrefixes: []),
        .init(id: "bun-cache", name: "Bun Install Cache", displayPath: "~/.bun/install/cache",
              scope: .contents([".bun/install/cache"]), safeDefault: true,
              warning: "Packages download again on the next install.", blockingBundlePrefixes: []),
        .init(id: "maven-repository", name: "Maven Repository", displayPath: "~/.m2/repository",
              scope: .contents([".m2/repository"]), safeDefault: false,
              warning: "Java builds download every dependency again, which can take a while offline.", blockingBundlePrefixes: []),
        .init(id: "cocoapods-repos", name: "CocoaPods Spec Repos", displayPath: "~/.cocoapods/repos",
              scope: .contents([".cocoapods/repos"]), safeDefault: false,
              warning: "Run pod repo update before your next pod install.", blockingBundlePrefixes: []),
        .init(id: "xcode-archives", name: "Xcode Archives", displayPath: "~/Library/Developer/Xcode/Archives",
              scope: .contents(["Library/Developer/Xcode/Archives"]), safeDefault: false,
              warning: "Archives hold the symbols for crash reports of shipped builds. Keep any release you still support.",
              blockingBundlePrefixes: xcode, movesToTrash: true),
        .init(id: "ollama-models", name: "Ollama Models", displayPath: "~/.ollama/models",
              scope: .contents([".ollama/models"]), safeDefault: false,
              warning: "Local AI models are downloaded again when you use them, often many gigabytes.", blockingBundlePrefixes: ["com.electron.ollama"], movesToTrash: true),
        .init(id: "huggingface-cache", name: "Hugging Face Models", displayPath: "~/.cache/huggingface/hub",
              scope: .contents([".cache/huggingface/hub"]), safeDefault: false,
              warning: "Downloaded models and datasets are fetched again when a script needs them.", blockingBundlePrefixes: [], movesToTrash: true),
        .init(id: "lmstudio-models", name: "LM Studio Models", displayPath: "~/.lmstudio/models",
              scope: .contents([".lmstudio/models"]), safeDefault: false,
              warning: "Models must be downloaded again inside LM Studio.", blockingBundlePrefixes: ["ai.elementlabs.lmstudio"], movesToTrash: true)
    ]

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "iso", "xip", "ipsw"]
    static let leftoverFolders = ["Library/Application Support", "Library/Preferences", "Library/Saved Application State",
                                  "Library/HTTPStorages", "Library/WebKit"]

    static let clutter: [CacheCategoryDefinition] = [
        .init(id: "old-installers", name: "Old Installers in Downloads", displayPath: "~/Downloads (.dmg, .pkg, .iso, .xip, .ipsw)",
              scope: .files("Downloads", extensions: installerExtensions, olderThanDays: 7), safeDefault: true,
              warning: "Installers you downloaded more than a week ago. They go to the Trash, so you can still get them back.",
              blockingBundlePrefixes: [], movesToTrash: true),
        .init(id: "ios-software-updates", name: "iPhone and iPad Software Updates", displayPath: "~/Library/iTunes/iPhone Software Updates",
              scope: .contents(["Library/iTunes/iPhone Software Updates", "Library/iTunes/iPad Software Updates"]), safeDefault: true,
              warning: "Old firmware files; Finder downloads a fresh one when you restore or update a device.", blockingBundlePrefixes: []),
        .init(id: "adobe-media-cache", name: "Adobe Media Cache", displayPath: "~/Library/Application Support/Adobe/Common",
              scope: .contents(["Library/Application Support/Adobe/Common/Media Cache Files", "Library/Application Support/Adobe/Common/Media Cache",
                                "Library/Application Support/Adobe/Common/Peak Files"]), safeDefault: true,
              warning: "Premiere Pro and After Effects rebuild audio and video previews when a project opens.", blockingBundlePrefixes: ["com.adobe."]),
        .init(id: "app-leftovers", name: "Leftovers from Deleted Apps", displayPath: "~/Library (settings and data of apps no longer installed)",
              scope: .orphans(leftoverFolders), safeDefault: false,
              warning: "Settings and data named after apps that are no longer installed. Check the list; reinstalling an app later starts it fresh. Moved to the Trash.",
              blockingBundlePrefixes: [], movesToTrash: true)
    ]

    static let directOnly: [CacheCategoryDefinition] = [
        .init(id: "xcodebuildmcp-cache", name: "XcodeBuildMCP Build Cache", displayPath: "~/Library/Developer/XcodeBuildMCP/workspaces",
              scope: .contents(["Library/Developer/XcodeBuildMCP/workspaces"]), safeDefault: true,
              warning: "Close XcodeBuildMCP first. Workspace state is preserved.", blockingBundlePrefixes: []),
        .init(id: "simulator-contents", name: "Simulator Contents", displayPath: "~/Library/Developer/CoreSimulator/Devices",
              scope: .contents(["Library/Developer/CoreSimulator/Devices"]), safeDefault: false,
              warning: "Installed simulator apps, app data, and simulator settings will be erased.", blockingBundlePrefixes: xcode + ["com.apple.iphonesimulator"])
    ]
}
