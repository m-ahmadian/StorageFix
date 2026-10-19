import AppKit

/// Answers whether an application with a bundle identifier is installed, so leftovers of deleted apps can be found.
public protocol InstalledApplicationsProviding: Sendable {
    func installedBundleIdentifiers() async -> InstalledApplicationIndex
}

/// Installed (or running) bundle identifiers. Matching is deliberately generous: anything sharing a vendor prefix with an
/// installed app (for example a helper of the same company) counts as installed and is never offered as a leftover.
public struct InstalledApplicationIndex: Sendable, Equatable {
    public let identifiers: Set<String>
    private let vendors: Set<String>

    public init(_ identifiers: Set<String>) {
        self.identifiers = Set(identifiers.map { $0.lowercased() })
        vendors = Set(self.identifiers.compactMap(Self.vendor))
    }

    public func contains(_ bundleID: String) -> Bool {
        let id = bundleID.lowercased()
        if identifiers.contains(id) { return true }
        guard let vendor = Self.vendor(of: id) else { return true }
        return vendors.contains(vendor)
    }

    /// "com.example.app" → "com.example". Identifiers with fewer than three parts are treated as unknown.
    static func vendor(of id: String) -> String? {
        let parts = id.split(separator: ".")
        return parts.count >= 3 ? parts.prefix(2).joined(separator: ".") : nil
    }

    /// The bundle identifier an item in Application Support, Preferences or Saved Application State is named after.
    public static func bundleID(forItemNamed name: String) -> String? {
        var id = name
        for suffix in [".plist", ".savedState", ".binarycookies"] where id.hasSuffix(suffix) { id = String(id.dropLast(suffix.count)) }
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } }),
              parts[0].allSatisfy(\.isLetter) else { return nil }
        let lower = id.lowercased()
        guard !lower.hasPrefix("com.apple."), !lower.hasPrefix("group."), !lower.hasPrefix("com.mehrdad.storagefix") else { return nil }
        return id
    }
}

/// Reads bundle identifiers from the standard application folders (two levels deep) plus running applications.
public struct WorkspaceInstalledApplications: InstalledApplicationsProviding {
    let roots: [URL]
    public init(home: URL) {
        roots = ["/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities"]
            .map { URL(fileURLWithPath: $0) } + [home.appending(path: "Applications")]
    }

    public func installedBundleIdentifiers() async -> InstalledApplicationIndex {
        let roots = roots
        var ids = await WorkspaceRunningApplications().runningBundleIdentifiers()
        for root in roots { ids.formUnion(Self.bundleIDs(in: root, depth: 2)) }
        return InstalledApplicationIndex(ids)
    }

    static func bundleIDs(in folder: URL, depth: Int) -> Set<String> {
        guard depth > 0, let children = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var ids: Set<String> = []
        for child in children {
            if child.pathExtension == "app" {
                if let id = Bundle(url: child)?.bundleIdentifier { ids.insert(id) }
            } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                ids.formUnion(bundleIDs(in: child, depth: depth - 1))
            }
        }
        return ids
    }
}
