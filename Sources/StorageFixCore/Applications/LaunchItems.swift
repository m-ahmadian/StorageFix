import Foundation

/// A launch agent or daemon: something macOS starts automatically at login or boot.
public struct LaunchItem: Identifiable, Equatable, Sendable {
    public enum Scope: String, Sendable { case user = "Your login", agents = "All users", daemons = "System" }
    public enum ProgramStatus: Sendable { case present, missing, unknown }
    public let path: String
    public let label: String
    public let program: String?
    public let scope: Scope
    public let status: ProgramStatus
    public let runsAtLoad: Bool
    public let keepsAlive: Bool
    public var id: String { path }
    /// The program it would start is gone, so it is most likely left behind by an uninstalled app.
    public var isLeftover: Bool { status == .missing }
    /// The app bundle that ships the program, when the program lives inside one.
    public var appName: String? {
        guard let program, let range = program.range(of: ".app/") else { return nil }
        return URL(fileURLWithPath: String(program[..<range.lowerBound]) + ".app").deletingPathExtension().lastPathComponent
    }
    public init(path: String, label: String, program: String?, scope: Scope, status: ProgramStatus, runsAtLoad: Bool, keepsAlive: Bool) {
        self.path = path; self.label = label; self.program = program; self.scope = scope; self.status = status
        self.runsAtLoad = runsAtLoad; self.keepsAlive = keepsAlive
    }
}

public protocol LaunchItemsProviding: Sendable {
    var permitsRemoval: Bool { get }
    func scan() async -> [LaunchItem]
    func moveToTrash(_ item: LaunchItem) async throws
}

public enum LaunchItemError: LocalizedError, Equatable, Sendable {
    case notRemovable
    public var errorDescription: String? { "Only items started for your own login can be moved to the Trash here." }
}

/// Reads launch agent and daemon property lists. Only your own LaunchAgents can be moved to the Trash, and only
/// in the direct edition.
public struct LaunchItemsService: LaunchItemsProviding {
    let folders: [(URL, LaunchItem.Scope)]
    public let permitsRemoval: Bool

    public init(home: URL, permitsRemoval: Bool, systemRoot: URL = URL(fileURLWithPath: "/")) {
        folders = [(home.appending(path: "Library/LaunchAgents"), .user),
                   (systemRoot.appending(path: "Library/LaunchAgents"), .agents),
                   (systemRoot.appending(path: "Library/LaunchDaemons"), .daemons)]
        self.permitsRemoval = permitsRemoval
    }

    public func scan() async -> [LaunchItem] {
        var items: [LaunchItem] = []
        for (folder, scope) in folders {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: file),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
                let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
                items.append(LaunchItem(path: file.path, label: plist["Label"] as? String ?? file.deletingPathExtension().lastPathComponent,
                                        program: program, scope: scope, status: program.map(Self.status) ?? .unknown,
                                        runsAtLoad: plist["RunAtLoad"] as? Bool ?? false, keepsAlive: plist["KeepAlive"] != nil))
            }
        }
        return items.sorted { a, b in
            if a.isLeftover != b.isLeftover { return a.isLeftover }
            return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
        }
    }

    public func moveToTrash(_ item: LaunchItem) async throws {
        let userFolder = folders[0].0.standardizedFileURL.path
        guard permitsRemoval, item.scope == .user,
              URL(fileURLWithPath: item.path).standardizedFileURL.deletingLastPathComponent().path == userFolder else { throw LaunchItemError.notRemovable }
        try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
    }

    /// Missing only when the nearest existing parent folder can be read and the next part of the path is absent;
    /// anything we cannot look into is reported as unknown rather than guessed.
    static func status(of program: String) -> LaunchItem.ProgramStatus {
        guard program.hasPrefix("/") else { return .unknown }
        let fm = FileManager.default
        if fm.fileExists(atPath: program) { return .present }
        var current = URL(fileURLWithPath: program)
        while current.path != "/" {
            let parent = current.deletingLastPathComponent()
            if fm.fileExists(atPath: parent.path) {
                guard let children = try? fm.contentsOfDirectory(atPath: parent.path) else { return .unknown }
                return children.contains(current.lastPathComponent) ? .unknown : .missing
            }
            current = parent
        }
        return .unknown
    }
}
