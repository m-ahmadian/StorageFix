import Accelerate
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Finds look-alike photos on this Mac with Apple's on-device Vision feature prints. Nothing leaves the device.
public actor VisionSimilarPhotoService: SimilarPhotoServiceProtocol {
    public static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp", "bmp"]
    /// Feature-print distance below which two photos count as look-alikes (burst shots, edits, resized copies).
    public static let defaultThreshold: Float = 0.45
    let maximumImages: Int
    let threshold: Float

    public init(maximumImages: Int = 4_000, threshold: Float = VisionSimilarPhotoService.defaultThreshold) {
        self.maximumImages = maximumImages; self.threshold = threshold
    }

    public func scan(in root: URL, progress: @escaping @Sendable (SimilarPhotoProgress) -> Void) async throws -> SimilarPhotoScan {
        let found = try Self.images(in: root)
        let limited = found.count > maximumImages
        let candidates = Array(found.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }.prefix(maximumImages))
        var photos: [SimilarPhoto] = [], prints: [[Float]] = []
        for (index, candidate) in candidates.enumerated() {
            try Task.checkCancellation()
            if let (photo, vector) = Self.analyze(candidate) { photos.append(photo); prints.append(vector) }
            if index % 8 == 0 || index == candidates.count - 1 { progress(SimilarPhotoProgress(analyzed: index + 1, total: candidates.count)) }
        }
        try Task.checkCancellation()
        let threshold = threshold
        let indexGroups = SimilarityGrouper.groups(count: photos.count, threshold: threshold) { Self.distance(prints[$0], prints[$1]) }
        let groups = indexGroups.map { SimilarPhotoGroup(photos: $0.map { photos[$0] }) }.sorted { $0.extraBytes > $1.extraBytes }
        return SimilarPhotoScan(groups: groups, analyzedCount: photos.count, wasLimited: limited)
    }

    public func moveToTrash(_ photos: [SimilarPhoto]) async -> [String] {
        var failed: [String] = []
        for photo in photos {
            let url = URL(fileURLWithPath: photo.path)
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey])
            // A file that changed since the scan is left alone; the person should look again first.
            guard let values, values.isSymbolicLink != true, Int64(values.fileSize ?? -1) == photo.bytes,
                  values.contentModificationDate == photo.modifiedAt else { failed.append(photo.path); continue }
            do { try FileManager.default.trashItem(at: url, resultingItemURL: nil) } catch { failed.append(photo.path) }
        }
        return failed
    }

    struct Candidate { let url: URL; let bytes: Int64; let modifiedAt: Date? }

    /// Regular image files below root; hidden files, symbolic links and packages (including Photos libraries) are skipped.
    static func images(in root: URL) throws -> [Candidate] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }
        var result: [Candidate] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            guard imageExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size > 0 else { continue }
            result.append(Candidate(url: url, bytes: Int64(size), modifiedAt: values.contentModificationDate))
        }
        return result
    }

    /// Reads dimensions and a downsampled thumbnail, then computes the feature print as a plain float vector.
    static func analyze(_ candidate: Candidate) -> (SimilarPhoto, [Float])? {
        guard let source = CGImageSourceCreateWithURL(candidate.url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 360, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFill
        guard (try? VNImageRequestHandler(cgImage: thumbnail).perform([request])) != nil,
              let observation = request.results?.first, let vector = floats(observation) else { return nil }
        let photo = SimilarPhoto(path: candidate.url.path, bytes: candidate.bytes, modifiedAt: candidate.modifiedAt, pixelWidth: width, pixelHeight: height)
        return (photo, vector)
    }

    static func floats(_ observation: VNFeaturePrintObservation) -> [Float]? {
        guard observation.elementType == .float else { return nil }
        return observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(observation.elementCount)) }
    }

    static func distance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        return sqrt(vDSP.distanceSquared(a, b))
    }
}
