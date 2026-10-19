import AppKit
import ImageIO
import SwiftUI

/// Small, downsampled preview loaded off the main thread and cached for the session.
struct PhotoThumbnail: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.12))
            if let image { Image(nsImage: image).resizable().scaledToFill() } else { ProgressView().controlSize(.small) }
        }
        .clipped()
        .task(id: path) { image = await ThumbnailCache.shared.thumbnail(for: path) }
        .accessibilityHidden(true)
    }
}

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var images: [String: NSImage] = [:]

    func thumbnail(for path: String) -> NSImage? {
        if let cached = images[path] { return cached }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 320, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        if images.count > 600 { images.removeAll() }
        images[path] = image
        return image
    }
}
