import Foundation
import StorageFixCore
import Testing

struct StorageSunburstTests {
    @Test func `Hierarchy shares one byte denominator and children exactly partition their parent angle`() {
        let root = URL(fileURLWithPath: "/fixture")
        let files = [DuplicateFile(path: "/fixture/folder/a", bytes: 30), DuplicateFile(path: "/fixture/folder/b", bytes: 10),
                     DuplicateFile(path: "/fixture/file", bytes: 60), DuplicateFile(path: "/outside/file", bytes: 999)]
        let result = StorageSunburst.segments(files: files, root: root, items: StorageMap.items(files: files, at: root))
        let inner = result.filter { !$0.isOuter }, outer = result.filter(\.isOuter)
        #expect(inner.count == 2 && outer.count == 2 && Set(result.map(\.id)).count == result.count)
        #expect(abs(inner.reduce(0) { $0 + $1.endFraction - $1.startFraction } - 1) < 0.000001)
        #expect(abs(outer.reduce(0) { $0 + $1.endFraction - $1.startFraction } - 0.4) < 0.000001)
        #expect(outer.allSatisfy { $0.startFraction >= 0 && $0.endFraction <= 1 })
        #expect(inner.first { $0.slice.name == "file" }?.extendsToEdge == true)
        #expect(inner.first { $0.slice.name == "folder" }?.extendsToEdge == false)
    }
    @Test func `Empty inventories and zero-byte entries do not create invalid arcs`() {
        let root = URL(fileURLWithPath: "/fixture")
        #expect(StorageSunburst.segments(files: [], root: root, items: []).isEmpty)
        let files = [DuplicateFile(path: "/fixture/empty", bytes: 0)]
        #expect(StorageSunburst.segments(files: files, root: root, items: StorageMap.items(files: files, at: root)).isEmpty)
    }
}
