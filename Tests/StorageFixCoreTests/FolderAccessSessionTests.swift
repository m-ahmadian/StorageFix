import Foundation
import StorageFixCore
import Testing

/// Disposable temporary folders and UserDefaults suites only.
@MainActor struct FolderAccessSessionTests {
    private func suite() throws -> (UserDefaults, String) {
        let name = "StorageFixAccess-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func `A remembered folder is restored on the next launch and forgetting removes it`() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "StorageFix-Access-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        FolderAccessSession(defaults: defaults).remember(folder)
        let relaunched = FolderAccessSession(defaults: defaults)
        #expect(relaunched.restoreRemembered().map(\.standardizedFileURL.path) == [folder.standardizedFileURL.path])
        relaunched.forgetRemembered()
        #expect(FolderAccessSession(defaults: defaults).restoreRemembered().isEmpty)
    }

    @Test func `Retained review folders are not remembered across launches`() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        FolderAccessSession(defaults: defaults).retain(FileManager.default.temporaryDirectory)
        #expect(FolderAccessSession(defaults: defaults).restoreRemembered().isEmpty)
    }

    @Test func `A bookmark that no longer resolves is dropped quietly`() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["/gone": Data([1, 2, 3])], forKey: "storagefix.rememberedFolders.v1")
        #expect(FolderAccessSession(defaults: defaults).restoreRemembered().isEmpty)
        #expect((defaults.dictionary(forKey: "storagefix.rememberedFolders.v1") ?? [:]).isEmpty)
    }
}
