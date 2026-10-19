import Foundation
import StorageFixCore
import Testing

/// Disposable temporary homes only.
struct AppLeftoverAndLaunchItemTests {
    private func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Leftover-\(UUID().uuidString)")
        let fm = FileManager.default
        for folder in ["Library/Application Support/com.acme.Editor", "Library/Application Support/Acme Editor", "Library/Application Support/com.acme.EditorPro",
                       "Library/Caches/com.acme.Editor", "Library/Saved Application State/com.acme.Editor.savedState", "Library/Preferences/ByHost",
                       "Library/Containers/com.acme.Editor", "Library/LaunchAgents", "Library/Application Support/Notes"] {
            try fm.createDirectory(at: home.appending(path: folder), withIntermediateDirectories: true)
        }
        for file in ["Library/Application Support/com.acme.Editor/db", "Library/Caches/com.acme.Editor/blob", "Library/Preferences/com.acme.Editor.plist",
                     "Library/Preferences/ByHost/com.acme.Editor.1234-ABCD.plist", "Library/Preferences/com.acme.EditorTools.plist"] {
            try Data(repeating: 1, count: 5_000).write(to: home.appending(path: file))
        }
        return home
    }

    @Test func `Leftovers are found by bundle identifier, name matches are flagged, and look-alike identifiers are skipped`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let finder = AppRelatedFilesFinder(home: home, includesContainers: false)
        let files = try await finder.relatedFiles(bundleID: "com.acme.Editor", appName: "Acme Editor")
        let names = Set(files.map(\.name))
        #expect(names == ["com.acme.Editor", "com.acme.Editor.plist", "com.acme.Editor.1234-ABCD.plist", "com.acme.Editor.savedState", "Acme Editor"])
        #expect(files.first { $0.name == "Acme Editor" }?.matchedByName == true)
        #expect(files.filter { $0.name != "Acme Editor" }.allSatisfy { !$0.matchedByName })
        #expect(!names.contains("com.acme.EditorPro") && !names.contains("com.acme.EditorTools.plist") && !names.contains("Containers"))
        let withContainers = try await AppRelatedFilesFinder(home: home, includesContainers: true).relatedFiles(bundleID: "com.acme.Editor", appName: "Acme Editor")
        #expect(withContainers.contains { $0.location == "Containers" })
    }

    @Test func `Apple apps, generic names and missing access never produce leftovers`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let finder = AppRelatedFilesFinder(home: home, includesContainers: false)
        #expect(try await finder.relatedFiles(bundleID: "com.apple.Notes", appName: "Notes").isEmpty)
        #expect(try await finder.relatedFiles(bundleID: "org.example.notes", appName: "Notes").isEmpty)
        let locked = AppRelatedFilesFinder(home: home, includesContainers: false) { false }
        await #expect(throws: RelatedFilesError.accessRequired) { try await locked.relatedFiles(bundleID: "com.acme.Editor", appName: "Acme Editor") }
    }

    @Test func `Only items that were found can be moved to the Trash`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let finder = AppRelatedFilesFinder(home: home, includesContainers: false)
        let files = try await finder.relatedFiles(bundleID: "com.acme.Editor", appName: "Acme Editor")
        let stranger = RelatedFile(path: home.appending(path: "Library/Preferences/com.acme.EditorTools.plist").path, bytes: 1, location: "Preferences", matchedByName: false)
        let plist = try #require(files.first { $0.name == "com.acme.Editor.plist" })
        #expect(await finder.moveToTrash([plist, stranger]) == [stranger.path])
        #expect(!FileManager.default.fileExists(atPath: plist.path) && FileManager.default.fileExists(atPath: stranger.path))
    }

    @Test func `Launch items report present, missing and unknown programs and only user items are removable`() async throws {
        let home = try makeHome(), system = home.appending(path: "system")
        defer { try? FileManager.default.removeItem(at: home) }
        let tool = home.appending(path: "bin/tool")
        try FileManager.default.createDirectory(at: tool.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: tool)
        try FileManager.default.createDirectory(at: system.appending(path: "Library/LaunchDaemons"), withIntermediateDirectories: true)
        func write(_ folder: URL, _ name: String, _ plist: [String: Any]) throws {
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: folder.appending(path: name))
        }
        let agents = home.appending(path: "Library/LaunchAgents")
        try write(agents, "com.acme.helper.plist", ["Label": "com.acme.helper", "ProgramArguments": [tool.path, "--run"], "RunAtLoad": true])
        try write(agents, "com.gone.updater.plist", ["Label": "com.gone.updater", "Program": home.appending(path: "Gone.app/Contents/MacOS/Updater").path])
        try write(agents, "notes.txt.plist", ["Label": "relative", "Program": "tool"])
        try write(system.appending(path: "Library/LaunchDaemons"), "com.acme.daemon.plist", ["Label": "com.acme.daemon", "Program": tool.path, "KeepAlive": true])
        let service = LaunchItemsService(home: home, permitsRemoval: true, systemRoot: system)
        let items = await service.scan()
        #expect(items.first?.label == "com.gone.updater" && items.first?.isLeftover == true && items.first?.appName == "Gone")
        #expect(items.first { $0.label == "com.acme.helper" }?.status == .present)
        #expect(items.first { $0.label == "relative" }?.status == .unknown)
        let daemon = try #require(items.first { $0.label == "com.acme.daemon" })
        #expect(daemon.scope == .daemons && daemon.keepsAlive)
        await #expect(throws: LaunchItemError.notRemovable) { try await service.moveToTrash(daemon) }
        await #expect(throws: LaunchItemError.notRemovable) { try await LaunchItemsService(home: home, permitsRemoval: false, systemRoot: system).moveToTrash(items[0]) }
        try await service.moveToTrash(items[0])
        #expect(!FileManager.default.fileExists(atPath: items[0].path))
    }
}
