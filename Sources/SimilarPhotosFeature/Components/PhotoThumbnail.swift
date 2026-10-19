import AppKit
import ImageIO
import SwiftUI

/// Small, downsampled preview decoded off the main thread and cached for the session.
struct PhotoThumbnail: View {
    let path: String
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.12))
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFill() }
        }
        .clipped()
        .task(id: path) { image = await ThumbnailCache.shared.thumbnail(for: path) }
        .accessibilityHidden(true)
    }
}

/// Thread-safe cache; decoding runs on background threads in parallel, and a tile scrolled away is skipped.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>(); cache.countLimit = 800; return cache
    }()

    func thumbnail(for path: String) async -> CGImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard !Task.isCancelled, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 240, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
        }.value
        if let image { cache.setObject(image, forKey: path as NSString) }
        return image
    }
}
