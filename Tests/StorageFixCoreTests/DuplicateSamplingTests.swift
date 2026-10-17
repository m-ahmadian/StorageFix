import Foundation
import StorageFixCore
import Testing

/// Disposable temporary fixtures only.
struct DuplicateSamplingTests {
    private let size = 200_000

    private func content(_ seed: UInt8, changeAt offset: Int? = nil) -> Data {
        var bytes = [UInt8](repeating: seed, count: size)
        if let offset { bytes[offset] &+= 1 }
        return Data(bytes)
    }

    @Test func `Given large files that differ only in the middle, when scanning, then full contents decide and they are not grouped`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try content(7).write(to: folder.appending(path: "a.bin"))
        try content(7, changeAt: size / 2).write(to: folder.appending(path: "b.bin"))
        let groups = try await FileSystemDuplicateService(roots: [folder]).scan()
        #expect(groups.isEmpty)
    }

    @Test func `Given large identical files and a same-size file differing at the tail, then only the identical set is grouped`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["one.bin", "two.bin", "three.bin"] { try content(9).write(to: folder.appending(path: name)) }
        try content(9, changeAt: size - 1).write(to: folder.appending(path: "tail.bin"))
        try content(9, changeAt: 0).write(to: folder.appending(path: "head.bin"))
        let groups = try await FileSystemDuplicateService(roots: [folder]).scan()
        #expect(groups.count == 1)
        let names = groups.first.map { ([$0.original] + $0.duplicates).map { URL(fileURLWithPath: $0.path).lastPathComponent }.sorted() }
        #expect(names == ["one.bin", "three.bin", "two.bin"])
    }

    @Test func `Given small equal-size files, then sampling is skipped and contents are compared in full`() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(repeating: 1, count: 1_000).write(to: folder.appending(path: "a"))
        try Data(repeating: 1, count: 1_000).write(to: folder.appending(path: "b"))
        try Data(repeating: 2, count: 1_000).write(to: folder.appending(path: "c"))
        let groups = try await FileSystemDuplicateService(roots: [folder]).scan()
        #expect(groups.count == 1 && groups.first?.duplicates.count == 1)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Sampling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
