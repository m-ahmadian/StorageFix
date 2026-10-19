import Foundation
import StorageFixCore
import Testing

/// Disposable folders only.
struct DuplicateProgressTests {
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock(); private var values: [DuplicateScanProgress] = []
        func add(_ value: DuplicateScanProgress) { lock.lock(); values.append(value); lock.unlock() }
        var all: [DuplicateScanProgress] { lock.lock(); defer { lock.unlock() }; return values }
    }

    private func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (name, byte) in [("a1", 1), ("a2", 1), ("a3", 1), ("b1", 2), ("b2", 2), ("c", 3)] as [(String, UInt8)] {
            try Data(repeating: byte, count: name == "c" ? 9_000 : 4_000).write(to: root.appending(path: name))
        }
        return root
    }

    @Test func `A scan reports listing, then comparing up to every same-size file`() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = Recorder()
        let groups = try await FileSystemDuplicateService(roots: [root]).scan(in: root) { recorder.add($0) }
        let values = recorder.all
        #expect(values.first?.phase == .listing)
        #expect(values.last == DuplicateScanProgress(phase: .comparing, completed: 5, total: 5) && values.last?.fraction == 1)
        #expect(groups.count == 1)
    }

    @Test func `After moving one copy to Trash, the remaining copies can be removed without a rescan`() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = FileSystemDuplicateService(roots: [root])
        let groups = try await service.scan(in: root) { _ in }
        let set = try #require(groups.first { $0.original.path.hasSuffix("a1") })
        try await service.remove(paths: [set.duplicates[0].path])
        try await service.remove(paths: [set.duplicates[1].path])
        #expect(FileManager.default.fileExists(atPath: set.original.path))
        // The last copy of a set is never removable.
        await #expect(throws: FileReviewError.self) { try await service.remove(paths: [set.original.path]) }
    }
}
