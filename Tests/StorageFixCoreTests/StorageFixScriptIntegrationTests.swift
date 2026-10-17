import Foundation
import StorageFixCore
import Testing

struct StorageFixScriptIntegrationTests {
    @Test func `Given an isolated home, when scanning, then all allow-listed categories appear`() throws {
        let homeURL = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: homeURL) }

        let report = try runScript(arguments: ["--scan", "--format", "json"], homeURL: homeURL)

        #expect(report.categories.count == 14)
        #expect(report.categories.contains { $0.id == "npm-cache" && $0.safeDefault })
        #expect(report.categories.contains { $0.id == "xcodebuildmcp-cache" && $0.safeDefault })
        #expect(report.categories.contains { $0.id == "claude-cache" && $0.safeDefault })
        #expect(report.categories.contains { $0.id == "user-cache-files" && !$0.safeDefault })
    }

    @Test func `Given caches and personal data, when cleaning selected logs, then personal data remains`() throws {
        let homeURL = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: homeURL) }
        let logsURL = homeURL.appending(path: "Library/Logs")
        let preservedURL = homeURL.appending(path: "Library/Application Support/Important/data.txt")
        try FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: preservedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("log".utf8).write(to: logsURL.appending(path: "app.log"))
        try Data("keep".utf8).write(to: preservedURL)

        let report = try runScript(
            arguments: ["--clean", "app-logs", "--format", "json"],
            homeURL: homeURL
        )

        let logsCategory = try #require(report.categories.first { $0.id == "app-logs" })
        #expect(logsCategory.status == .cleaned)
        #expect(logsCategory.bytesAfter == 0)
        #expect(FileManager.default.fileExists(atPath: preservedURL.path))
    }

    @Test func `Given optional application caches, when explicitly cleaning them, then personal data remains`() throws {
        let homeURL = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: homeURL) }
        let cacheURL = homeURL.appending(path: "Library/Caches/com.example.app/cache.db")
        let preservedURL = homeURL.appending(path: "Library/Application Support/Important/data.txt")
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preservedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8_192).write(to: cacheURL)
        try Data("keep".utf8).write(to: preservedURL)

        let scan = try runScript(arguments: ["--scan", "--format", "json"], homeURL: homeURL)
        let scannedCache = try #require(scan.categories.first { $0.id == "user-cache-files" })
        #expect(scannedCache.bytesAfter > 0)

        let cleaned = try runScript(arguments: ["--clean", "user-cache-files", "--format", "json"], homeURL: homeURL)
        let cleanedCache = try #require(cleaned.categories.first { $0.id == "user-cache-files" })
        #expect(cleanedCache.status == .cleaned)
        #expect(cleanedCache.bytesAfter == 0)
        #expect(FileManager.default.fileExists(atPath: preservedURL.path))
    }

    @Test func `Given named and optional caches, when scanning and cleaning optional caches, then named caches are not double counted or removed`() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let named = home.appending(path: "Library/Caches/org.swift.swiftpm/cache")
        let other = home.appending(path: "Library/Caches/example/cache")
        for file in [named, other] {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 1, count: 8192).write(to: file)
        }
        let scan = try runScript(arguments: ["--scan", "--format", "json"], homeURL: home)
        let namedSize = try #require(scan.categories.first { $0.id == "swiftpm-cache" }).bytesAfter
        let otherSize = try #require(scan.categories.first { $0.id == "user-cache-files" }).bytesAfter
        #expect(namedSize > 0 && otherSize > 0 && namedSize == otherSize)
        _ = try runScript(arguments: ["--clean", "user-cache-files", "--format", "json"], homeURL: home)
        #expect(FileManager.default.fileExists(atPath: named.path))
        #expect(!FileManager.default.fileExists(atPath: other.path))
    }
    @Test func `Given a redirected Library folder, when cleaning logs, then data outside the allow-list is preserved`() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let outside = home.appending(path: "personal")
        let log = outside.appending(path: "Logs/important")
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: log)
        try FileManager.default.createSymbolicLink(at: home.appending(path: "Library"), withDestinationURL: outside)
        let report = try runScript(arguments: ["--clean", "app-logs", "--format", "json"], homeURL: home, expectedExit: 1)
        #expect(report.categories.first { $0.id == "app-logs" }?.status == .failed)
        #expect(FileManager.default.fileExists(atPath: log.path))
    }

    private func runScript(arguments: [String], homeURL: URL, expectedExit: Int32 = 0) throws -> CleanupReport {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path] + arguments
        process.environment = ["HOME": homeURL.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        #expect(
            process.terminationStatus == expectedExit,
            Comment(rawValue: String(decoding: errorData, as: UTF8.self))
        )
        return try JSONDecoder().decode(CleanupReport.self, from: outputData)
    }

    private func makeTemporaryHome() throws -> URL {
        let homeURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: ".test-fixtures/StorageFixTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        return homeURL.resolvingSymlinksInPath()
    }

    private var scriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Scripts/storage-fix.sh")
    }
}
