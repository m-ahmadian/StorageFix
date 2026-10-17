import Foundation
import StorageFixCore
import Testing

struct InventoryScannerTests {
    private let root = URL(fileURLWithPath: "/fixture")

    @Test func `Partial coverage preserves readable files and all observed reasons`() throws {
        let result = try scan(FixtureMetadataSource())
        #expect(result.files.count == 3)
        #expect(result.logicalBytes == 150)
        #expect(result.knownAllocatedBytes == 128)
        #expect(result.unknownAllocatedCount == 1)
        #expect(result.files.filter(\.isSharedLink).count == 1)
        for reason in [InventoryIssueReason.hidden, .package, .cloudPlaceholder, .symbolicLink,
                       .sharedLink, .unknownSize, .inaccessible, .disappeared, .changed] {
            #expect(result.coverage.counts[reason] == 1)
        }
        #expect(result.coverage.hasReadErrors && !result.wasCancelled)
        #expect(result.volume?.isReadOnly == true)
        #expect(InventorySummary(scan: result).title.contains("Partial"))
    }

    @Test func `Inspection options include hidden and package metadata but never cloud contents`() throws {
        var options = InventoryOptions()
        options.includesHiddenFiles = true; options.includesPackageContents = true
        let result = try scan(FixtureMetadataSource(), options: options)
        #expect(result.logicalBytes == 180)
        #expect(result.coverage.counts[.hidden] == nil && result.coverage.counts[.package] == nil)
        #expect(result.coverage.counts[.cloudPlaceholder] == 1)
        #expect(!result.files.contains { $0.path.contains("never-read") })
    }

    @Test func `Cancellation retains the metadata already visited`() async throws {
        let task = Task {
            try scan(FixtureMetadataSource(cancelAfterFirst: true))
        }
        let result = try await task.value
        #expect(result.wasCancelled && result.files.count == 1)
        #expect(InventorySummary(scan: result).title.contains("Cancelled"))
    }

    @Test func `Diagnostics retain bounded samples while counting every error`() throws {
        let result = try scan(FixtureMetadataSource(errorCount: 100))
        #expect(result.coverage.counts[.inaccessible] == 100)
        #expect(result.coverage.examples.count == InventoryCoverage.exampleLimit)
    }

    @Test func `Progress carries session identity and final observed counts`() async throws {
        let (stream, continuation) = AsyncStream<InventoryProgress>.makeStream()
        let session = UUID()
        let result = try InventoryScanner(source: FixtureMetadataSource()).scan(root: root,
            options: InventoryOptions(), sessionID: session, progress: { continuation.yield($0) })
        continuation.finish()
        var updates: [InventoryProgress] = []
        for await update in stream { updates.append(update) }
        #expect(updates.first?.visitedCount == 0)
        #expect(updates.last?.fileCount == result.files.count)
        #expect(updates.allSatisfy { $0.sessionID == session })
    }

    @Test func `Outside scope and traversal paths never contribute bytes`() throws {
        let result = try scan(FixtureMetadataSource(extraPaths: ["/fixture-other/file", "/fixture/../outside/file"]))
        #expect(result.logicalBytes == 150)
        #expect(result.coverage.counts[.unsupported] == 2)
    }

    private func scan(_ source: FixtureMetadataSource, options: InventoryOptions = InventoryOptions()) throws -> InventoryScan {
        try InventoryScanner(source: source).scan(root: root, options: options, sessionID: UUID(), progress: { _ in })
    }
}

private struct FixtureMetadataSource: InventoryMetadataSource {
    var cancelAfterFirst = false
    var errorCount = 1
    var extraPaths: [String] = []

    func walk(root: URL, visit: (InventoryMetadata) throws -> Bool, issue: @escaping (InventoryIssue) -> Void) throws {
        _ = try visit(file("a", bytes: 100, allocated: 64))
        if cancelAfterFirst {
            withUnsafeCurrentTask { $0?.cancel() }
            throw CancellationError()
        }
        _ = try visit(file("empty", bytes: 0, allocated: nil))
        var shared = file("shared", bytes: 50, allocated: 64)
        shared.identity = "device:inode"; shared.linkCount = 2
        _ = try visit(shared)
        var link = shared; link = file("second-link", bytes: 50, allocated: 64)
        link.identity = shared.identity; link.linkCount = 2
        _ = try visit(link)
        var hidden = file(".hidden", bytes: 10); hidden.isHidden = true
        _ = try visit(hidden)
        var package = InventoryMetadata(path: "/fixture/Bundle.app")
        package.isDirectory = true; package.isPackage = true
        if try visit(package) { _ = try visit(file("Bundle.app/data", bytes: 20)) }
        var cloud = InventoryMetadata(path: "/fixture/cloud")
        cloud.isCloudPlaceholder = true; cloud.isDirectory = true
        if try visit(cloud) { Issue.record("Cloud placeholder was entered"); _ = try visit(file("cloud/never-read", bytes: 999)) }
        var symlink = InventoryMetadata(path: "/fixture/link")
        symlink.isSymbolicLink = true; symlink.isDirectory = true
        if try visit(symlink) { Issue.record("Symbolic link was entered") }
        _ = try visit(file("unknown", bytes: nil))
        for path in extraPaths { var item = InventoryMetadata(path: path); item.isRegularFile = true; item.bytes = 999; _ = try visit(item) }
        for index in 0..<errorCount { issue(InventoryIssue(path: "/fixture/locked\(index)", reason: .inaccessible)) }
        issue(InventoryIssue(path: "/fixture/vanished", reason: .disappeared))
        issue(InventoryIssue(path: "/fixture/mutating", reason: .changed))
    }

    func volume(at root: URL) -> InventoryVolume? {
        InventoryVolume(name: "External fixture", capacityBytes: 1_000, availableBytes: 500, isReadOnly: true)
    }

    private func file(_ name: String, bytes: Int64?, allocated: Int64? = nil) -> InventoryMetadata {
        var item = InventoryMetadata(path: "/fixture/\(name)")
        item.isRegularFile = true; item.bytes = bytes; item.allocatedBytes = allocated
        return item
    }
}
