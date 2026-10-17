import Foundation
import StorageFixCore
import Testing

struct ReviewFileOperationsTests {
    @Test func `A live disposable regular file passes identity and timestamp validation`() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("review".utf8).write(to: root.appending(path: "file"))
        let file = try #require(try await FileInventoryService().scan(in: root).first)
        let operations = ReviewFileOperations(policy: ReviewFilePolicy(protectedRoots: []))
        try await operations.validate(ReviewQueueItem(file: file, root: root, origins: [.files]))
    }

    @Test(arguments: ["replace", "symlink", "hardlink", "edit"])
    func `Changed metadata, identity and link boundaries are rejected before writes`(change: String) async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "file")
        try Data("review".utf8).write(to: url)
        let file = try #require(try await FileInventoryService().scan(in: root).first)
        switch change {
        case "replace": try FileManager.default.removeItem(at: url); try Data("other contents".utf8).write(to: url)
        case "symlink": try FileManager.default.removeItem(at: url); try FileManager.default.createSymbolicLink(at: url, withDestinationURL: root)
        case "hardlink": try FileManager.default.linkItem(at: url, to: root.appending(path: "second"))
        default: try Data("changed".utf8).write(to: url)
        }
        let operations = ReviewFileOperations(policy: ReviewFilePolicy(protectedRoots: []))
        await #expect(throws: ReviewQueueError.self) { try await operations.validate(ReviewQueueItem(file: file, root: root, origins: [.files])) }
    }

    @Test func `Duplicate content protection rejects a changed kept file without moving its copy`() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("original".utf8).write(to: root.appending(path: "a"))
        try Data("original".utf8).write(to: root.appending(path: "b"))
        let group = try #require(try await FileSystemDuplicateService(roots: [root]).scan().first)
        let protection = ReviewDuplicateProtection(group: group, root: root)
        let copy = try #require(group.duplicates.first)
        let operations = ReviewFileOperations(policy: ReviewFilePolicy(protectedRoots: []))
        try await operations.validate(protection, selected: [copy.path], preflight: true)
        try Data("modified".utf8).write(to: URL(fileURLWithPath: group.original.path))
        if let date = group.original.modifiedAt { try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: group.original.path) }
        await #expect(throws: ReviewQueueError.self) {
            try await operations.moveToTrash(ReviewQueueItem(file: copy, root: root, origins: [.duplicates]), protections: [protection])
        }
        #expect(FileManager.default.fileExists(atPath: copy.path))
    }

    private func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "QueueFiles-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
