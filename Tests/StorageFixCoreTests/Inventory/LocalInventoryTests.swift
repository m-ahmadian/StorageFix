import Darwin
import Foundation
import StorageFixCore
import Testing

struct LocalInventoryTests {
    @Test func `Local metadata inventory counts hard links once, skips boundaries and records volume`() async throws {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "Inventory-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "source")
        try Data(repeating: 1, count: 16).write(to: file)
        try FileManager.default.linkItem(at: file, to: folder.appending(path: "hard-link"))
        try Data().write(to: folder.appending(path: "empty"))
        try Data([1]).write(to: folder.appending(path: ".hidden"))
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "outside"), withDestinationURL: URL(fileURLWithPath: "/"))
        let result = try await FileInventoryService().inventory(in: folder, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        #expect(result.logicalBytes == 16 && result.files.count == 2)
        #expect(result.files.contains { $0.isSharedLink })
        #expect(result.coverage.counts[.sharedLink] == 1)
        #expect(result.coverage.counts[.hidden] == 1 && result.coverage.counts[.symbolicLink] == 1)
        #expect(result.volume?.capacityBytes != nil)
        #expect(result.coverage.hasReadErrors == false)
    }
}

extension LocalInventoryTests {
    @Test func `APFS clones retain distinct logical files without claiming uniquely allocated bytes`() async throws {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "CloneInventory-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appending(path: "original")
        let clone = folder.appending(path: "clone")
        try Data(repeating: 1, count: 65_536).write(to: original)
        try #require(clonefile(original.path, clone.path, 0) == 0, "Fixture volume must support native clones")
        let result = try await FileInventoryService().inventory(in: folder, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        #expect(result.files.count == 2 && result.logicalBytes == 131_072)
        #expect(Set(result.files.compactMap(\.fileIdentity)).count == 2)
        #expect(result.files.allSatisfy { !$0.isSharedLink })
        #expect(InventorySummary(scan: result).sizeDetail.contains("not reclaimable-space"))
    }
}

extension LocalInventoryTests {
    @Test func `A chosen package root requires inspection consent before enumerating contents`() async throws {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "Package-\(UUID()).app")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data([1, 2, 3]).write(to: folder.appending(path: "data"))
        let service = FileInventoryService()
        let excluded = try await service.inventory(in: folder, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        #expect(excluded.files.isEmpty && excluded.coverage.counts[.package] == 1)
        var options = InventoryOptions(); options.includesPackageContents = true
        let included = try await service.inventory(in: folder, options: options, sessionID: UUID(), progress: { _ in })
        #expect(included.logicalBytes == 3 && included.files.count == 1)
    }
}
