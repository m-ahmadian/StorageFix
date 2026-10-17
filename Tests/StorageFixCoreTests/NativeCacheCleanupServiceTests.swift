import Foundation
import StorageFixCore
import Testing

/// Disposable temporary "home" folders only; nothing outside them is created or removed.
struct NativeCacheCleanupServiceTests {
    struct Running: RunningApplicationsProviding {
        let ids: Set<String>
        func runningBundleIdentifiers() async -> Set<String> { ids }
    }

    private func makeHome() throws -> (home: URL, outside: URL) {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Native-\(UUID().uuidString)")
        let home = base.appending(path: "home"), outside = base.appending(path: "outside")
        for folder in ["Library/Caches/Google/Chrome", "Library/Caches/com.apple.Safari", "Library/Caches/SomeApp",
                       "Library/Logs/App", ".npm/_cacache", "Library/Developer/Xcode"] {
            try FileManager.default.createDirectory(at: home.appending(path: folder), withIntermediateDirectories: true)
        }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let files = ["Library/Caches/Google/Chrome/data", "Library/Caches/com.apple.Safari/db", "Library/Caches/SomeApp/blob",
                     "Library/Logs/App/run.log", ".npm/_cacache/pkg"]
        for file in files { try Data(repeating: 7, count: 50_000).write(to: home.appending(path: file)) }
        try Data(repeating: 1, count: 10_000).write(to: outside.appending(path: "keep.txt"))
        // A link inside a cache pointing out of Home, and a cache root that is itself a link out of Home.
        try FileManager.default.createSymbolicLink(at: home.appending(path: "Library/Caches/SomeApp/escape"), withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: home.appending(path: "Library/Developer/Xcode/DerivedData"), withDestinationURL: outside)
        return (home, outside)
    }

    @Test func `Given the sandbox, scanning requires the Home folder and rejects any other folder`() async throws {
        let (home, outside) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home.deletingLastPathComponent()) }
        let service = NativeCacheCleanupService(home: home, requiresGrant: true, runningApplications: Running(ids: []))
        #expect(service.requiredFolder?.path == home.standardizedFileURL.path)
        await #expect(throws: NativeCleanupError.self) { try await service.scan() }
        await #expect(throws: NativeCleanupError.self) { try await service.grantAccess(to: outside) }
        try await service.grantAccess(to: home)
        let report = try await service.scan()
        #expect(report.categories.first { $0.id == "google-cache" }?.bytesAfter ?? 0 > 0)
        #expect(report.categories.first { $0.id == "xcode-derived-data" }?.bytesAfter == 0)
    }

    @Test func `Cleaning deletes only selected cache contents and keeps folders, Apple caches and anything outside Home`() async throws {
        let (home, outside) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home.deletingLastPathComponent()) }
        let service = NativeCacheCleanupService(home: home, requiresGrant: false, runningApplications: Running(ids: []))
        let report = try await service.clean(categoryIDs: ["google-cache", "user-cache-files", "xcode-derived-data"])
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: home.appending(path: "Library/Caches/Google/Chrome").path))
        #expect(fm.fileExists(atPath: home.appending(path: "Library/Caches/Google").path))
        #expect(!fm.fileExists(atPath: home.appending(path: "Library/Caches/SomeApp").path))
        #expect(fm.fileExists(atPath: home.appending(path: "Library/Caches/com.apple.Safari/db").path))
        #expect(fm.fileExists(atPath: home.appending(path: "Library/Logs/App/run.log").path))
        #expect(fm.fileExists(atPath: home.appending(path: ".npm/_cacache/pkg").path))
        #expect(fm.fileExists(atPath: outside.appending(path: "keep.txt").path))
        #expect(report.categories.first { $0.id == "google-cache" }?.status == .cleaned)
        #expect(report.categories.first { $0.id == "google-cache" }?.bytesReclaimed ?? 0 > 0)
        #expect(report.categories.first { $0.id == "app-logs" }?.status == .scanned)
    }

    @Test func `A running owner app blocks its category and nothing in it is deleted`() async throws {
        let (home, _) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home.deletingLastPathComponent()) }
        let service = NativeCacheCleanupService(home: home, requiresGrant: false, runningApplications: Running(ids: ["com.google.Chrome"]))
        let report = try await service.clean(categoryIDs: ["google-cache", "app-logs"])
        #expect(report.categories.first { $0.id == "google-cache" }?.status == .blocked)
        #expect(FileManager.default.fileExists(atPath: home.appending(path: "Library/Caches/Google/Chrome/data").path))
        #expect(!FileManager.default.fileExists(atPath: home.appending(path: "Library/Logs/App").path))
    }

    @Test func `Unknown or unselected categories are never touched`() async throws {
        let (home, _) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home.deletingLastPathComponent()) }
        let service = NativeCacheCleanupService(home: home, requiresGrant: false, runningApplications: Running(ids: []))
        let report = try await service.clean(categoryIDs: ["not-a-category"])
        #expect(report.categories.allSatisfy { $0.status == .scanned })
        #expect(FileManager.default.fileExists(atPath: home.appending(path: "Library/Caches/SomeApp/blob").path))
    }

    @Test func `Through the protocol, the engine's own access methods are used, not the defaults`() async throws {
        let (home, _) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home.deletingLastPathComponent()) }
        let service: any CleanupServiceProtocol = NativeCacheCleanupService(home: home, requiresGrant: true, runningApplications: Running(ids: []))
        #expect(await service.hasAccess == false)
        await #expect(throws: NativeCleanupError.self) { try await service.grantAccess(to: home.deletingLastPathComponent()) }
        try await service.grantAccess(to: home)
        #expect(await service.hasAccess)
    }
}
