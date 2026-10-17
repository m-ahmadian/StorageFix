import CryptoKit
import Darwin
import Foundation

/// Filesystem work runs on this actor, never on the UI actor. All writes use native Trash.
public actor ReviewFileOperations: ReviewFileOperationsProtocol {
    private let policy: any ReviewFilePolicyProtocol
    private static let hashChunkSize = 1_048_576
    public init(policy: any ReviewFilePolicyProtocol) { self.policy = policy }

    public func validate(_ item: ReviewQueueItem) throws {
        try Task.checkCancellation()
        try policy.validate(item.file, root: item.root)
        _ = try ReviewedFileVersion.read(item.file, root: item.root)
    }

    public func validate(_ protection: ReviewDuplicateProtection, selected: Set<String>, preflight: Bool) throws {
        guard !selected.contains(protection.kept.path),
              protection.members.contains(protection.kept) else { throw ReviewQueueError.keptCopy }
        let members = (preflight ? protection.members : protection.members.filter { $0.path == protection.kept.path || selected.contains($0.path) })
            .sorted { left, right in left.path != protection.kept.path && right.path == protection.kept.path }
        for member in members {
            try Task.checkCancellation()
            try policy.validate(member, root: protection.root)
            guard try hash(member, root: protection.root) == protection.digest else { throw ReviewQueueError.changed(member.path) }
        }
    }

    public func moveToTrash(_ item: ReviewQueueItem, protections: [ReviewDuplicateProtection]) throws {
        try validate(item)
        for protection in protections { try validate(protection, selected: [item.id], preflight: false) }
        for protection in protections {
            try validate(ReviewQueueItem(file: protection.kept, root: protection.root, origins: [.duplicates]))
        }
        try validate(item)
        try Task.checkCancellation()
        try FileManager.default.trashItem(at: URL(fileURLWithPath: item.id), resultingItemURL: nil)
        // A cancellation arriving after a successful mutation must still be recorded as moved.
    }

    private func hash(_ file: DuplicateFile, root: URL) throws -> String {
        let before = try ReviewedFileVersion.read(file, root: root)
        let descriptor = open(file.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw ReviewQueueError.inaccessible(file.path) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        guard try ReviewedFileVersion.read(descriptor: descriptor) == before else { throw ReviewQueueError.changed(file.path) }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: Self.hashChunkSize), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        guard try ReviewedFileVersion.read(descriptor: descriptor) == before,
              try ReviewedFileVersion.read(file, root: root) == before else { throw ReviewQueueError.changed(file.path) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
