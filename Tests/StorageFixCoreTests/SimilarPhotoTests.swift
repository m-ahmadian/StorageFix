import AppKit
import Foundation
import StorageFixCore
import Testing

/// Synthetic images in disposable folders only.
struct SimilarPhotoTests {
    @Test func `Grouping links chains of close items and ignores loners`() {
        let points: [Float] = [0, 0.1, 0.2, 5, 9, 9.05]
        let groups = SimilarityGrouper.groups(count: points.count, threshold: 0.15) { abs(points[$0] - points[$1]) }
        #expect(groups == [[0, 1, 2], [4, 5]])
        #expect(SimilarityGrouper.groups(count: 0, threshold: 1) { _, _ in 0 }.isEmpty)
    }

    @Test func `The suggested keeper is the sharpest, then largest, then newest photo`() {
        let small = SimilarPhoto(path: "/a.jpg", bytes: 900, modifiedAt: Date(), pixelWidth: 100, pixelHeight: 100)
        let big = SimilarPhoto(path: "/b.jpg", bytes: 500, modifiedAt: .distantPast, pixelWidth: 400, pixelHeight: 300)
        let group = SimilarPhotoGroup(photos: [small, big])
        #expect(group.suggestedKeep == "/b.jpg" && group.photos.first == big && group.extraBytes == 900)
    }

    @Test func `Vision groups a resized, re-encoded copy and keeps a different picture apart`() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StorageFix-Photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.write(scene: 1, size: 1200, brightness: 0, to: folder.appending(path: "beach.png"), type: .png)
        try Self.write(scene: 1, size: 700, brightness: 0.04, to: folder.appending(path: "beach-copy.jpg"), type: .jpeg)
        try Self.write(scene: 2, size: 1000, brightness: 0, to: folder.appending(path: "city.png"), type: .png)
        try Data("not an image".utf8).write(to: folder.appending(path: "notes.txt"))

        let service = VisionSimilarPhotoService()
        let scan = try await service.scan(in: folder) { _ in }
        #expect(scan.analyzedCount == 3)
        let names = scan.groups.map { Set($0.photos.map { URL(fileURLWithPath: $0.path).lastPathComponent }) }
        #expect(names == [["beach.png", "beach-copy.jpg"]], "groups: \(names)")
        #expect(scan.groups.first.map { URL(fileURLWithPath: $0.suggestedKeep).lastPathComponent } == "beach.png")
    }

    @Test func `A photo that changed after the scan is not moved to the Trash`() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StorageFix-Photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "a.png")
        try Self.write(scene: 3, size: 300, brightness: 0, to: url, type: .png)
        let stale = SimilarPhoto(path: url.path, bytes: 1, modifiedAt: nil, pixelWidth: 300, pixelHeight: 300)
        #expect(await VisionSimilarPhotoService().moveToTrash([stale]) == [url.path])
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    /// Draws a deterministic "scene" of coloured shapes; the same scene at another size is a look-alike.
    static func write(scene: Int, size: Int, brightness: CGFloat, to url: URL, type: NSBitmapImageRep.FileType) throws {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size * 3 / 4, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let w = CGFloat(size), h = CGFloat(size * 3 / 4)
        var seed = UInt64(scene) &* 6364136223846793005 &+ 1442695040888963407
        func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
        NSColor(calibratedHue: next(), saturation: 0.5, brightness: 0.6 + brightness, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()
        for _ in 0..<14 {
            NSColor(calibratedHue: next(), saturation: 0.8, brightness: 0.5 + next() * 0.4 + brightness, alpha: 1).setFill()
            let rect = NSRect(x: next() * w, y: next() * h, width: (0.1 + next() * 0.35) * w, height: (0.1 + next() * 0.35) * h)
            (next() > 0.5 ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: type, properties: [.compressionFactor: 0.8])!.write(to: url)
    }
}
