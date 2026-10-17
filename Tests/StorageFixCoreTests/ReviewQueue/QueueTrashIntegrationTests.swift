import Foundation
import StorageFixCore
import Testing

@MainActor struct QueueTrashIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_VERIFY_TRASH"] == "1"))
    func `Our disposable duplicate copy moves through the queue and restores unchanged from native Trash`() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.resolvingSymlinksInPath().appending(path: "QueueTrash-\(UUID())")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let data = Data("StorageFix queue disposable fixture".utf8)
        for suffix in ["a", "b"] { try data.write(to: root.appending(path: "StorageFix-Queue-\(UUID())-\(suffix).dat")) }
        let group = try #require(try await FileSystemDuplicateService(roots: [root]).scan().first)
        let copy = try #require(group.duplicates.first)
        let source = URL(fileURLWithPath: copy.path)
        let trash = try manager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: source, create: true)
        let destination = trash.appending(path: source.lastPathComponent)
        defer { if manager.fileExists(atPath: destination.path) { try? manager.moveItem(at: destination, to: source) } }
        let policy = ReviewFilePolicy(protectedRoots: [])
        let queue = ReviewQueue(policy: policy, operations: ReviewFileOperations(policy: policy))
        queue.registerDuplicates([group], root: root)
        #expect(queue.add(paths: [copy.path], origin: .duplicates).addedCount == 1)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.movedCount == 1)
        #expect(!manager.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: URL(fileURLWithPath: group.original.path)) == data)
        #expect(try Data(contentsOf: destination) == data)
        try manager.moveItem(at: destination, to: source)
        #expect(try Data(contentsOf: source) == data)
    }
}
