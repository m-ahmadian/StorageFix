import Foundation
import StorageFixCore
import Testing

struct StorageWorkspaceServiceTests {
    @Test func `Given nested files and an outside path, when mapping a folder, then only direct children contribute`() {
        let files = [DuplicateFile(path: "/test/photos/a.jpg", bytes: 20), DuplicateFile(path: "/test/photos/b.jpg", bytes: 30), DuplicateFile(path: "/test/document.pdf", bytes: 10), DuplicateFile(path: "/testing/outside", bytes: 100)]
        let items = StorageMap.items(files: files, at: URL(fileURLWithPath: "/test"))
        #expect(items.map(\.bytes) == [50, 10]); #expect(items.first?.isFolder == true); #expect(items.first?.fileCount == 2)
        #expect(StorageMap.items(files: files, at: URL(fileURLWithPath: "/test/photos")).count == 2)
    }
    @Test func `Given an unreviewed file, when moving it to Trash, then no mutation is requested`() async throws {
        let recorder = TrashRecorder(); let service = FileBrowserService(trash: { await recorder.record($0) })
        await #expect(throws: FileBrowserError.self) { try await service.moveToTrash(paths: ["/unknown"]) }
        #expect(await recorder.paths.isEmpty)
    }
    @Test func `Given reviewed files with a changed member, when moving multiple files to Trash, then preflight blocks every mutation`() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let a = folder.appending(path: "a"), b = folder.appending(path: "b")
        try Data("safe".utf8).write(to: a); try Data("safe".utf8).write(to: b)
        let recorder = TrashRecorder(); let service = FileBrowserService(trash: { await recorder.record($0) })
        let scanned = try await service.scan(in: folder)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: b.path)
        await #expect(throws: FileBrowserError.self) { try await service.moveToTrash(paths: Set(scanned.map(\.path))) }
        #expect(await recorder.paths.isEmpty)
    }
    @Test func `Given a reviewed file, when moving it to Trash, then the reviewed path is used and a fresh scan is required`() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        try Data("safe".utf8).write(to: folder.appending(path: "file"))
        let recorder = TrashRecorder(); let service = FileBrowserService(trash: { await recorder.record($0) })
        let scanned = try await service.scan(in: folder); let file = try #require(scanned.first)
        try await service.moveToTrash(paths: [file.path]); #expect(await recorder.paths == [file.path])
        await #expect(throws: FileBrowserError.self) { try await service.moveToTrash(paths: [file.path]) }
    }
    @Test func `Given an application bundle and a symbolic link to it, when scanning apps, then only the actual bundle appears`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeApp(in: root)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "Alias.app"), withDestinationURL: app)
        let apps = try await ApplicationService(roots: [root]).scan()
        #expect(apps.count == 1); #expect(apps.first?.version == "1.0"); #expect(apps.first?.bytes ?? 0 > 0)
    }
    @Test func `Given a running reviewed application, when removing it, then no Trash operation is requested`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeApp(in: root); let runningPath = app.standardizedFileURL.path
        let recorder = TrashRecorder()
        let service = ApplicationService(roots: [root], runningPaths: { [runningPath] }, trash: { await recorder.record($0) })
        let record = try #require(try await service.scan().first)
        await #expect(throws: ApplicationReviewError.self) { try await service.moveToTrash(record) }
        #expect(await recorder.paths.isEmpty)
    }
    @Test func `Given an app with same-size changed contents, when removing it, then the changed snapshot blocks mutation`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeApp(in: root); let recorder = TrashRecorder()
        let service = ApplicationService(roots: [root], runningPaths: { [] }, trash: { await recorder.record($0) })
        let record = try #require(try await service.scan().first)
        try Data("different".utf8).write(to: app.appending(path: "Contents/payload"))
        await #expect(throws: ApplicationReviewError.self) { try await service.moveToTrash(record) }
        #expect(await recorder.paths.isEmpty)
    }
    @Test func `Given a stopped unchanged app, edition policy controls whether native Trash is requested`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeApp(in: root); let recorder = TrashRecorder()
        let service = ApplicationService(roots: [root], runningPaths: { [] }, trash: { await recorder.record($0) })
        let record = try #require(try await service.scan().first)
        if DistributionMode.current == .appStore {
            await #expect(throws: ApplicationReviewError.self) { try await service.moveToTrash(record) }
            #expect(await recorder.paths.isEmpty)
        } else {
            try await service.moveToTrash(record)
            #expect(await recorder.paths == [record.path])
            await #expect(throws: ApplicationReviewError.self) { try await service.moveToTrash(record) }
        }
    }
    @Test func `Given a reviewed file with a new hard link, when moving it to Trash, then mutation is refused`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "original"), link = root.appending(path: "link")
        try Data("content".utf8).write(to: file)
        let recorder = TrashRecorder(), service = FileBrowserService(trash: { await recorder.record($0) })
        _ = try await service.scan(in: root)
        try FileManager.default.linkItem(at: file, to: link)
        await #expect(throws: FileBrowserError.self) { try await service.moveToTrash(paths: [file.path]) }
        #expect(await recorder.paths.isEmpty)
    }
    @Test func `Given a read-only app service, when removing a reviewed bundle, then no mutation occurs`() async throws {
        let root = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeApp(in: root)
        let recorder = TrashRecorder(), service = ApplicationService(roots: [root], permitsRemoval: false, trash: { await recorder.record($0) })
        let app = try #require(try await service.scan().first)
        await #expect(throws: ApplicationReviewError.self) { try await service.moveToTrash(app) }
        #expect(await recorder.paths.isEmpty)
    }
    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StorageFix3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); return folder
    }
    private func makeApp(in root: URL) throws -> URL {
        let app = root.appending(path: "Example.app"), contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "com.storagefix.fixture.\(UUID().uuidString)", "CFBundleName": "Example", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.0"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appending(path: "Info.plist"))
        try Data("unchanged".utf8).write(to: contents.appending(path: "payload")); return app
    }
}
private actor TrashRecorder {
    var paths: [String] = []
    func record(_ url: URL) { paths.append(url.path) }
}
