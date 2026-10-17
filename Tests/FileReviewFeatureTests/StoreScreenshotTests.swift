import AppKit
import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import LargeFilesFeature
import StorageFixCore
import StorageFixDesignSystem
import StorageMapFeature
import SwiftUI
import Testing
import WorkspaceFeature

@MainActor
struct StoreScreenshotTests {
    private enum Canvas {
        static let width: CGFloat = 1280
        static let height: CGFloat = 800
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_STORE_SCREENSHOTS"] != nil),
          arguments: [WorkspaceSection.overview, .duplicates, .files, .map])
    func `Given sample folder contents, when rendering Store screens, then opaque screenshot candidates are produced`(section: WorkspaceSection) async throws {
        let output = try #require(ProcessInfo.processInfo.environment["STORAGEFIX_STORE_SCREENSHOTS"])
        let suite = "StorageFixStoreScreenshot-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = makeWorkspace(defaults: defaults)
        await vm.review()
        vm.select(section)
        let bitmap = try render(WorkspaceView(viewModel: vm))
        let opaque = try makeOpaque(bitmap)
        #expect(opaque.pixelsWide * 10 == opaque.pixelsHigh * 16)
        #expect(opaque.hasAlpha == false)
        let data = try #require(opaque.representation(using: .png, properties: [:]))
        let filename = section == .overview ? "01-overview" : section == .duplicates ? "02-duplicates" : section == .files ? "03-files" : "04-map"
        try data.write(to: URL(fileURLWithPath: output).appending(path: "\(filename).png"))
    }

    private func makeWorkspace(defaults: UserDefaults) -> WorkspaceViewModel {
        let root = StoreScreenshotFixtures.root
        return WorkspaceViewModel(cleanup: CleanupViewModel(service: FixtureCleanupService()),
            duplicates: DuplicateViewModel(service: StoreScreenshotFixtures.Duplicates(), scopeDescription: root.path),
            files: LargeFilesViewModel(scope: root, service: StoreScreenshotFixtures.Files()),
            map: StorageMapViewModel(root: root, service: FixtureFileService()),
            apps: ApplicationsViewModel(service: FixtureApplicationService(), permitsRemoval: false, requiresFolderSelection: true),
            defaults: defaults, edition: .appStore)
    }

    private func render(_ view: some View) throws -> NSBitmapImageRep {
        let frame = CGRect(x: 0, y: 0, width: Canvas.width, height: Canvas.height)
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        hosting.frame = frame
        hosting.appearance = NSAppearance(named: .aqua)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: frame))
        hosting.cacheDisplay(in: frame, to: bitmap)
        return bitmap
    }

    private func makeOpaque(_ bitmap: NSBitmapImageRep) throws -> NSBitmapImageRep {
        let image = try #require(bitmap.cgImage)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        context.draw(image, in: bounds)
        return NSBitmapImageRep(cgImage: try #require(context.makeImage()))
    }
}
