import Foundation
import StorageFixCore
import Testing

struct FileReviewTests {
    @Test func `Given distinct contents of equal size, when scanning, then every matching set is returned`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for (name, content) in [("a.txt", "first"), ("b.txt", "first"), ("c.txt", "other"), ("d.txt", "other"), ("e.txt", "alone")] {
            try Data(content.utf8).write(to: folder.appending(path: name))
        }
        let groups = try await FileSystemDuplicateService(roots: [folder]).scan()
        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.original.bytes == 5 && $0.duplicates.count == 1 })
    }

    @Test func `Given overlapping roots and symbolic links, when scanning, then files are counted once and links are skipped`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let nested = folder.appending(path: "nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appending(path: "file.txt")
        try Data("content".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "alias.txt"), withDestinationURL: file)
        let files = try FileInventory.files(in: [folder, nested])
        #expect(files.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path } == [file.standardizedFileURL.path])
    }

    @Test func `Given hidden files and hard links, when scanning, then nonreclaimable entries are excluded`() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "shared.txt")
        try Data("content".utf8).write(to: file)
        try FileManager.default.linkItem(at: file, to: folder.appending(path: "link.txt"))
        try Data("secret".utf8).write(to: folder.appending(path: ".hidden"))
        #expect(try FileInventory.files(in: [folder]).isEmpty)
    }

    @Test func `Given a changed kept file, when removing a reviewed copy, then removal is blocked`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let kept = folder.appending(path: "a.txt")
        let copy = folder.appending(path: "b.txt")
        try Data("first".utf8).write(to: kept); try Data("first".utf8).write(to: copy)
        let service = FileSystemDuplicateService(roots: [folder])
        _ = try await service.scan()
        try Data("other".utf8).write(to: kept)
        await #expect(throws: FileReviewError.self) { try await service.remove(paths: [copy.path]) }
        #expect(FileManager.default.fileExists(atPath: copy.path))
    }

    @Test func `Given all copies or an unreviewed path, when removing files, then removal is blocked`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = folder.appending(path: "a.txt"), b = folder.appending(path: "b.txt")
        try Data("same".utf8).write(to: a); try Data("same".utf8).write(to: b)
        let service = FileSystemDuplicateService(roots: [folder])
        _ = try await service.scan()
        await #expect(throws: FileReviewError.self) { try await service.remove(paths: [a.path, b.path]) }
        await #expect(throws: FileReviewError.self) { try await service.remove(paths: [folder.appending(path: "unknown").path]) }
        #expect(FileManager.default.fileExists(atPath: a.path))
        #expect(FileManager.default.fileExists(atPath: b.path))
    }

    @Test func `Given a file replaced by a symbolic link, when removing copies, then removal is blocked`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = folder.appending(path: "a.txt"), b = folder.appending(path: "b.txt")
        try Data("same".utf8).write(to: a); try Data("same".utf8).write(to: b)
        let service = FileSystemDuplicateService(roots: [folder]); _ = try await service.scan()
        try FileManager.default.removeItem(at: b)
        try FileManager.default.createSymbolicLink(at: b, withDestinationURL: a)
        await #expect(throws: FileReviewError.self) { try await service.remove(paths: [b.path]) }
        #expect(FileManager.default.fileExists(atPath: a.path))
    }

    @Test func `Given an unavailable folder, when scanning, then an actionable error is returned`() async {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        await #expect(throws: FileReviewError.self) { _ = try await FileSystemDuplicateService(roots: [folder]).scan() }
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
