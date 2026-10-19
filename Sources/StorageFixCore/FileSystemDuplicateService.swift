import AppKit
import CryptoKit
import Foundation

public actor FileSystemDuplicateService: DuplicateServiceProtocol {
    private let roots: [URL]
    private var reviewedGroups: [DuplicateGroup] = []
    public init(roots: [URL]) { self.roots = roots }

    public func scan() async throws -> [DuplicateGroup] { try await scan(in: nil) }

    public func scan(in root: URL?) async throws -> [DuplicateGroup] { try await scan(in: root) { _ in } }

    // Exact signature so this, not the protocol default, is used through the existential.
    public func scan(in root: URL?, progress: @escaping @Sendable (DuplicateScanProgress) -> Void) async throws -> [DuplicateGroup] {
        reviewedGroups = []
        let roots = root.map { [$0] } ?? roots
        // Runs off the actor and off the main thread; the interface stays responsive and only receives progress.
        let task = Task.detached(priority: .utility) { try Self.groups(in: roots, progress: progress) }
        let groups = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        reviewedGroups = groups
        return groups
    }

    public nonisolated func reveal(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    public func remove(paths: Set<String>) async throws {
        guard !paths.isEmpty else { return }
        let eligible = Set(reviewedGroups.flatMap { [$0.original] + $0.duplicates }.map(\.path))
        guard paths.isSubset(of: eligible) else { throw FileReviewError.unreviewedFile }
        // Validate every affected set before moving any file. A changed original must never
        // turn its reviewed copies into the last remaining copy of the scanned content.
        for group in reviewedGroups {
            let members = [group.original] + group.duplicates
            guard members.contains(where: { paths.contains($0.path) }) else { continue }
            guard members.contains(where: { !paths.contains($0.path) }) else { throw FileReviewError.unreviewedFile }
            for file in members { try Self.validate(file, hash: group.id) }
        }
        for path in paths.sorted() {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        }
        // Remaining sets stay reviewed, so more copies can be removed without a rescan.
        reviewedGroups = reviewedGroups.compactMap { group in
            let left = ([group.original] + group.duplicates).filter { !paths.contains($0.path) }
            return left.count > 1 ? DuplicateGroup(id: group.id, original: left[0], duplicates: Array(left.dropFirst())) : nil
        }
    }

    private static func groups(in roots: [URL], progress: @Sendable (DuplicateScanProgress) -> Void) throws -> [DuplicateGroup] {
        progress(DuplicateScanProgress(phase: .listing, completed: 0, total: 0))
        let inventory = try FileInventory.files(in: roots).filter { !ReviewExclusions.excludes($0.path) }
        let candidates = Dictionary(grouping: inventory, by: \.bytes).values.filter { $0.count > 1 }
        let total = candidates.reduce(0) { $0 + $1.count }
        var done = 0, reported = 0
        let step = max(1, total / 200)   // at most ~200 updates, so the interface is never flooded
        progress(DuplicateScanProgress(phase: .comparing, completed: 0, total: total))
        var result: [DuplicateGroup] = []
        for sameSize in candidates {
            let sampled = try sampleCollisions(sameSize)
            done += sameSize.count
            if done - reported >= step || done == total {
                reported = done
                progress(DuplicateScanProgress(phase: .comparing, completed: done, total: total))
            }
            for files in sampled {
                var byHash: [String: [DuplicateFile]] = [:]
                for file in files {
                    try Task.checkCancellation()
                    byHash[try hash(URL(fileURLWithPath: file.path)), default: []].append(file)
                }
                for (digest, matches) in byHash where matches.count > 1 {
                    let sorted = matches.sorted { $0.path < $1.path }
                    result.append(DuplicateGroup(id: digest, original: sorted[0], duplicates: Array(sorted.dropFirst())))
                }
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    /// Bytes read from each end of a large file before deciding a full-content comparison is needed.
    static let sampleBytes = 16_384

    /// Splits same-size files by a head/tail sample. Different samples prove different contents,
    /// so only colliding files are fully hashed; grouping still relies on the full-content digest.
    static func sampleCollisions(_ files: [DuplicateFile]) throws -> [[DuplicateFile]] {
        guard let size = files.first?.bytes, size > Int64(sampleBytes * 2) else { return [files] }
        var bySample: [String: [DuplicateFile]] = [:]
        for file in files {
            try Task.checkCancellation()
            bySample[try sample(URL(fileURLWithPath: file.path), bytes: size), default: []].append(file)
        }
        return bySample.values.filter { $0.count > 1 }.sorted { ($0.first?.path ?? "") < ($1.first?.path ?? "") }
    }

    private static func sample(_ url: URL, bytes: Int64) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        digest.update(data: try handle.read(upToCount: sampleBytes) ?? Data())
        try handle.seek(toOffset: UInt64(bytes - Int64(sampleBytes)))
        digest.update(data: try handle.read(upToCount: sampleBytes) ?? Data())
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func validate(_ file: DuplicateFile, hash expected: String) throws {
        let url = URL(fileURLWithPath: file.path)
        guard url.resolvingSymlinksInPath().standardizedFileURL.path == url.standardizedFileURL.path else {
            throw FileReviewError.changedFile(file.path)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == file.bytes, try hash(url) == expected else {
            throw FileReviewError.changedFile(file.path)
        }
    }

    private static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
