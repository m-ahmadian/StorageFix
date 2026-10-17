import Foundation
import StorageFixCore
import Testing

struct NestedInventoryTests {
    @Test func `Visible regular siblings do not prevent descent into later folders`() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Nested-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ["a.txt", "b.txt", "nested/inside.txt", "nested/deeper/deep.txt", "z-folder/end.txt"]
        for path in paths {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: url)
        }
        let scan = try await FileInventoryService().inventory(in: root, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        #expect(scan.files.count == paths.count)
        #expect(scan.logicalBytes == Int64(paths.count))
        #expect(scan.coverage.counts.isEmpty)
    }
}
