import AppKit
import SwiftUI

/// Exports the sidebar's native disk mark into macOS app icon sizes.
@main
@MainActor
private enum AppIconExporter {
    private struct Icon: View {
        var body: some View {
            Image(systemName: DesignSystem.Brand.symbol)
                .font(.system(size: DesignSystem.Brand.iconSymbolSize))
                .foregroundStyle(DesignSystem.Brand.foreground)
                .frame(width: DesignSystem.Brand.iconTile, height: DesignSystem.Brand.iconTile)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Brand.iconRadius))
                .frame(width: DesignSystem.Brand.iconCanvas, height: DesignSystem.Brand.iconCanvas)
        }
    }

    private enum ExportError: Error {
        case missingOutputDirectory
        case renderingFailed
    }

    static func main() throws {
        guard let destination = CommandLine.arguments.dropFirst().first else {
            throw ExportError.missingOutputDirectory
        }
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            try export(size: size, scale: 1, directory: directory)
            try export(size: size, scale: 2, directory: directory)
        }
    }

    private static func export(size: Int, scale: Int, directory: URL) throws {
        let renderer = ImageRenderer(content: Icon())
        renderer.scale = CGFloat(size * scale) / DesignSystem.Brand.iconCanvas
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ExportError.renderingFailed
        }
        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(size)x\(size)\(suffix).png"
        try data.write(to: directory.appendingPathComponent(filename))
    }
}
