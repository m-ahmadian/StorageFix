import Foundation
import StorageFixCore
import Testing

struct FileInventoryServiceTests {
    @Test func `Given disposable visible files, when scanning through the read-only service, then their inventory is returned`() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StorageFixMap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "sample")
        try Data("sample".utf8).write(to: file)
        let files = try await FileInventoryService().scan(in: folder)
        #expect(files.count == 1 && files.first?.bytes == 6)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func `Given a missing folder, when inventory scanning fails, then the error reaches the caller`() async {
        let missing = URL(fileURLWithPath: "/private/tmp/StorageFixMissing-\(UUID().uuidString)")
        await #expect(throws: FileReviewError.self) { try await FileInventoryService().scan(in: missing) }
    }

    @Test func `Given an already cancelled scan, when starting inventory, then cancellation reaches the caller`() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await FileInventoryService().scan(in: URL(fileURLWithPath: "/not-scanned"))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
