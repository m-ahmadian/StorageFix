import AppKit
@testable import CleanupFeature
import StorageFixCore
import SwiftUI
import Testing

@MainActor
struct CleanupVisualSnapshotTests {
    private static let snapshotSize = CGSize(width: 1_440, height: 1_024)

    @Test func `Given a scanned cleanup screen, when rendering, then a full-size image is produced`() async throws {
        configureApplicationIcon()
        let viewModel = CleanupViewModel(service: SnapshotCleanupService())
        await viewModel.scan()
        let view = CleanupView(
            viewModel: viewModel,
            scansOnAppear: false,
            isListScrollable: true
        )
        let image = try render(view)
        #expect(image.size == Self.snapshotSize)
        try writeSnapshotIfRequested(image)
    }

    private func render(_ view: CleanupView) throws -> NSImage {
        let frame = CGRect(origin: .zero, size: Self.snapshotSize)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = frame
        hostingView.appearance = NSAppearance(named: .aqua)
        hostingView.layoutSubtreeIfNeeded()
        let representation = try #require(
            hostingView.bitmapImageRepForCachingDisplay(in: frame)
        )
        hostingView.cacheDisplay(in: frame, to: representation)
        let image = NSImage(size: Self.snapshotSize)
        image.addRepresentation(representation)
        return image
    }

    private func configureApplicationIcon() {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = projectURL.appending(path: "Assets/StorageFix-AppIcon-Approved.png")
        if let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    private func writeSnapshotIfRequested(_ image: NSImage) throws {
        guard let path = ProcessInfo.processInfo.environment["STORAGEFIX_SNAPSHOT_PATH"] else {
            return
        }
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        let pngData = try #require(representation.representation(using: .png, properties: [:]))
        try pngData.write(to: URL(fileURLWithPath: path))
    }
}

private struct SnapshotCleanupService: CleanupServiceProtocol {
    func scan() async throws -> CleanupReport { .snapshotFixture }

    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { .snapshotFixture }
}

private extension CleanupReport {
    static let snapshotFixture = CleanupReport(
        mode: "scan",
        freeBytesBefore: 412_600_000_000,
        freeBytesAfter: 412_600_000_000,
        freeBytesReclaimed: 0,
        categories: [
            snapshotCategory("xcode-derived-data", "Xcode Derived Data", 4_900_000_000),
            snapshotCategory("xcodebuildmcp-cache", "XcodeBuildMCP Build Cache", 1_200_000_000),
            snapshotCategory("xcode-doc-cache", "Xcode Documentation Cache", 600_000_000),
            snapshotCategory("swiftpm-cache", "Swift Package Manager Cache", 1_800_000_000),
            snapshotCategory("npm-cache", "npm and npx Cache", 1_600_000_000),
            snapshotCategory("node-gyp-cache", "node-gyp Cache", 400_000_000),
            snapshotCategory("google-cache", "Google Application Cache", 1_100_000_000),
            snapshotCategory("claude-cache", "Claude Desktop Cache", 900_000_000),
            snapshotCategory("adobe-cache", "Adobe Cache", 700_000_000),
            snapshotCategory("codex-runtime-cache", "Codex Runtime Cache", 300_000_000),
            snapshotCategory("app-logs", "Application Logs", 500_000_000),
            snapshotCategory("simulator-contents", "Simulator Contents", 3_500_000_000),
            snapshotCategory("ios-device-support", "iOS Device Support", 900_000_000)
        ]
    )

    static func snapshotCategory(
        _ id: String,
        _ name: String,
        _ bytes: Int64
    ) -> CleanupCategory {
        CleanupCategory(
            id: id,
            name: name,
            path: "~/Library/\(name.replacingOccurrences(of: " ", with: ""))",
            safeDefault: id != "simulator-contents" && id != "ios-device-support",
            warning: id == "simulator-contents" ? "Simulator data will be erased." : "",
            bytesBefore: bytes,
            bytesAfter: bytes
        )
    }
}
