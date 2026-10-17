import Foundation
import StorageFixCore
import Testing

struct StorageMapIndexTests {
    @Test func `Every indexed level reconciles with the existing inventory projection`() throws {
        let root = URL(fileURLWithPath: "/fixture")
        let files = [DuplicateFile(path: "/fixture/nested/a", bytes: 10), DuplicateFile(path: "/fixture/nested/deep/b", bytes: 20),
            DuplicateFile(path: "/fixture/zero", bytes: 0), DuplicateFile(path: "/fixture/top", bytes: 30),
            DuplicateFile(path: "/elsewhere/ignored", bytes: 100)]
        let index = try StorageMapIndex(files: files, root: root)
        for path in ["/fixture", "/fixture/nested", "/fixture/nested/deep", "/elsewhere"] {
            let folder = URL(fileURLWithPath: path)
            #expect(index.items(at: folder) == (path == "/elsewhere" ? [] : StorageMap.items(files: files, at: folder)))
        }
        let items = index.items(at: root)
        #expect(items.reduce(0) { $0 + $1.bytes } == 60)
        #expect(StorageSunburst.segments(files: files, root: root, items: items, index: index) == StorageSunburst.segments(files: files, root: root, items: items))
    }
    @Test func `Noncanonical and off-scope paths cannot enter the index`() throws {
        let files = ["/fixture/../escape", "/fixture/a//b", "/fixture/a/./b", "/fixture/a/", "/fixture-other/b", "/fixture/a"].map { DuplicateFile(path: $0, bytes: 1) }
        let index = try StorageMapIndex(files: files, root: URL(fileURLWithPath: "/fixture"))
        #expect(index.items(at: URL(fileURLWithPath: "/fixture")).map(\.path) == ["/fixture/a"])
    }
    @Test func `Index construction cooperates with cancellation`() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try StorageMapIndex(files: [], root: URL(fileURLWithPath: "/fixture"))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
