import Foundation

/// One image found while looking for look-alike photos.
public struct SimilarPhoto: Identifiable, Equatable, Hashable, Sendable {
    public let path: String
    public let bytes: Int64
    public let modifiedAt: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public var id: String { path }
    public var pixelCount: Int { pixelWidth * pixelHeight }
    public init(path: String, bytes: Int64, modifiedAt: Date?, pixelWidth: Int, pixelHeight: Int) {
        self.path = path; self.bytes = bytes; self.modifiedAt = modifiedAt; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
    }
}

/// Photos that look alike. `suggestedKeep` is advice only and is never selected for removal.
public struct SimilarPhotoGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let photos: [SimilarPhoto]
    public let suggestedKeep: String
    public init(photos: [SimilarPhoto]) {
        let best = SimilarPhotoGroup.best(of: photos)
        self.photos = [best] + photos.filter { $0.path != best.path }.sorted { $0.path < $1.path }
        suggestedKeep = best.path
        id = best.path
    }
    /// Space freed if every photo except the suggested one were removed.
    public var extraBytes: Int64 { photos.filter { $0.path != suggestedKeep }.reduce(0) { $0 + $1.bytes } }

    /// Highest resolution, then largest file, then newest.
    static func best(of photos: [SimilarPhoto]) -> SimilarPhoto {
        photos.max { a, b in
            if a.pixelCount != b.pixelCount { return a.pixelCount < b.pixelCount }
            if a.bytes != b.bytes { return a.bytes < b.bytes }
            return (a.modifiedAt ?? .distantPast) < (b.modifiedAt ?? .distantPast)
        }!
    }
}

public struct SimilarPhotoProgress: Equatable, Sendable {
    public let analyzed: Int
    public let total: Int
    public init(analyzed: Int, total: Int) { self.analyzed = analyzed; self.total = total }
}

public protocol SimilarPhotoServiceProtocol: Sendable {
    func scan(in root: URL, progress: @escaping @Sendable (SimilarPhotoProgress) -> Void) async throws -> SimilarPhotoScan
    /// Moves photos to the Trash after confirming each is unchanged since the scan. Returns the paths that failed.
    func moveToTrash(_ photos: [SimilarPhoto]) async -> [String]
}

public struct SimilarPhotoScan: Equatable, Sendable {
    public let groups: [SimilarPhotoGroup]
    public let analyzedCount: Int
    /// True when the folder held more images than one scan compares; only the newest were analyzed.
    public let wasLimited: Bool
    public init(groups: [SimilarPhotoGroup], analyzedCount: Int, wasLimited: Bool) {
        self.groups = groups; self.analyzedCount = analyzedCount; self.wasLimited = wasLimited
    }
}

/// Groups items whose pairwise distance is below a threshold (single-link, union–find). Pure and deterministic.
public enum SimilarityGrouper {
    public static func groups(count: Int, threshold: Float, distance: (Int, Int) -> Float) -> [[Int]] {
        var parent = Array(0..<count)
        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        for i in 0..<count {
            for j in (i + 1)..<max(i + 1, count) where distance(i, j) < threshold {
                let a = root(i), b = root(j)
                if a != b { parent[max(a, b)] = min(a, b) }
            }
        }
        var buckets: [Int: [Int]] = [:]
        for i in 0..<count { buckets[root(i), default: []].append(i) }
        return buckets.values.filter { $0.count > 1 }.sorted { $0[0] < $1[0] }
    }
}
