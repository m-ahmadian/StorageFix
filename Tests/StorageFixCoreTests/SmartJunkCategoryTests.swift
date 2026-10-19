import Foundation
import StorageFixCore
import Testing

/// Installers and leftovers in disposable temporary "home" folders. Their items go to the Trash, never deleted outright.
struct SmartJunkCategoryTests {
    struct Running: RunningApplicationsProviding { func runningBundleIdentifiers() async -> Set<String> { [] } }
    struct Installed: InstalledApplicationsProviding {
        let ids: Set<String>
        var reliable = true
        func installedBundleIdentifiers() async -> InstalledApplicationIndex? { reliable ? InstalledApplicationIndex(ids) : nil }
    }

    private func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Junk-\(UUID().uuidString)")
        let fm = FileManager.default
        for folder in ["Downloads/Project.app", "Library/Application Support/com.gone.Editor", "Library/Application Support/com.kept.Writer",
                       "Library/Application Support/com.kept.Helper", "Library/Application Support/com.apple.Mail",
                       "Library/Application Support/Notes App", "Library/Preferences", "Library/Saved Application State/com.gone.Editor.savedState"] {
            try fm.createDirectory(at: home.appending(path: folder), withIntermediateDirectories: true)
        }
        for file in ["Downloads/Setup.dmg", "Downloads/Tool.PKG", "Downloads/report.pdf", "Library/Application Support/com.gone.Editor/db",
                     "Library/Preferences/com.gone.Editor.plist", "Library/Preferences/com.kept.Writer.plist", "Library/Preferences/.GlobalPreferences.plist"] {
            try Data(repeating: 3, count: 20_000).write(to: home.appending(path: file))
        }
        return home
    }

    private func service(_ home: URL, daysAhead: Double) -> NativeCacheCleanupService {
        NativeCacheCleanupService(home: home, requiresGrant: false, runningApplications: Running(),
            installedApplications: Installed(ids: ["com.kept.Writer"]), now: { Date().addingTimeInterval(daysAhead * 86_400) })
    }

    @Test func `Old installers in Downloads are listed and moved to the Trash, other files stay`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let scan = try await service(home, daysAhead: 30).scan()
        let installers = try #require(scan.categories.first { $0.id == "old-installers" })
        #expect(installers.items == ["Setup.dmg", "Tool.PKG"] && installers.movesToTrash && installers.safeDefault)
        let report = try await service(home, daysAhead: 30).clean(categoryIDs: ["old-installers"])
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: home.appending(path: "Downloads/Setup.dmg").path))
        #expect(fm.fileExists(atPath: home.appending(path: "Downloads/report.pdf").path))
        #expect(fm.fileExists(atPath: home.appending(path: "Downloads/Project.app").path))
        #expect(report.categories.first { $0.id == "old-installers" }?.status == .cleaned)
    }

    @Test func `Installers downloaded this week are not offered`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let scan = try await service(home, daysAhead: 0).scan()
        #expect(scan.categories.first { $0.id == "old-installers" }?.items.isEmpty == true)
    }

    @Test func `Leftovers of deleted apps are found; installed vendors, Apple and plain names are kept`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let scan = try await service(home, daysAhead: 30).scan()
        let leftovers = try #require(scan.categories.first { $0.id == "app-leftovers" })
        #expect(leftovers.items == ["com.gone.Editor", "com.gone.Editor.plist", "com.gone.Editor.savedState"])
        #expect(!leftovers.safeDefault && leftovers.movesToTrash && leftovers.bytesAfter > 0)
        _ = try await service(home, daysAhead: 30).clean(categoryIDs: ["app-leftovers"])
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: home.appending(path: "Library/Preferences/com.gone.Editor.plist").path))
        for kept in ["Library/Application Support/com.kept.Writer", "Library/Application Support/com.kept.Helper",
                     "Library/Application Support/com.apple.Mail", "Library/Application Support/Notes App",
                     "Library/Preferences/com.kept.Writer.plist", "Library/Preferences/.GlobalPreferences.plist"] {
            #expect(fm.fileExists(atPath: home.appending(path: kept).path), "\(kept) must stay")
        }
    }

    @Test func `When installed apps cannot be read, no leftovers are offered at all`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let blind = NativeCacheCleanupService(home: home, requiresGrant: false, runningApplications: Running(),
            installedApplications: Installed(ids: [], reliable: false), now: { Date().addingTimeInterval(30 * 86_400) })
        _ = try await blind.clean(categoryIDs: ["app-leftovers"])
        #expect(try await blind.scan().categories.first { $0.id == "app-leftovers" }?.bytesAfter == 0)
        #expect(FileManager.default.fileExists(atPath: home.appending(path: "Library/Preferences/com.gone.Editor.plist").path))
    }

    @Test func `Launch Services can vouch for an app outside the standard folders`() {
        let index = InstalledApplicationIndex([], lookup: { $0 == "com.portable.App" })
        #expect(index.contains("com.portable.App") && !index.contains("com.gone.Editor"))
    }

    @Test func `Recently changed leftovers are never offered`() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let scan = try await service(home, daysAhead: 0).scan()
        #expect(scan.categories.first { $0.id == "app-leftovers" }?.items.isEmpty == true)
    }

    @Test(arguments: [
        ("com.gone.Editor.plist", "com.gone.Editor"), ("org.example.tool.savedState", "org.example.tool"),
        ("com.apple.Safari", nil), ("group.com.x.y", nil), ("Notes App", nil), (".GlobalPreferences.plist", nil),
        ("com.two", nil), ("1password.app.x", nil)
    ] as [(String, String?)])
    func `Item names map to bundle identifiers conservatively`(name: String, expected: String?) {
        #expect(InstalledApplicationIndex.bundleID(forItemNamed: name) == expected)
    }

    @Test func `An installed app protects every identifier from the same vendor`() {
        let index = InstalledApplicationIndex(["com.docker.docker"])
        #expect(index.contains("com.docker.helper") && index.contains("COM.DOCKER.DOCKER"))
        #expect(!index.contains("com.other.app"))
        #expect(index.contains("weird"))
    }

    @Test func `Every category in either catalog has a unique id and stays inside Home`() {
        let ids = CacheCategoryCatalog.direct.map(\.id)
        #expect(ids.count == Set(ids).count)
        #expect(Set(CacheCategoryCatalog.standard.map(\.id)).isSubset(of: Set(ids)))
        #expect(!CacheCategoryCatalog.standard.contains { $0.id == "simulator-contents" })
    }
}
