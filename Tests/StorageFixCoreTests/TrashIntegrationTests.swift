import Foundation
import StorageFixCore
import Testing

struct TrashIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_VERIFY_TRASH"] == "1"))
    func `Given our disposable file, when reviewed removal uses Finder Trash, then the file can be restored unchanged`() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "StorageFix-Trash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "StorageFix-disposable-\(UUID().uuidString).dat"), data = Data("Disposable StorageFix end-to-end test".utf8)
        try data.write(to: file)
        let capture = TrashDestination()
        let service = FileBrowserService(trash: { source in
            var destination: NSURL?
            try FileManager.default.trashItem(at: source, resultingItemURL: &destination)
            if let destination { await capture.set(destination as URL) }
        })
        let reviewed = try #require(try await service.scan(in: root).first)
        try await service.moveToTrash(paths: [reviewed.path])
        let destination = try #require(await capture.url)
        defer { if FileManager.default.fileExists(atPath: destination.path) { try? FileManager.default.moveItem(at: destination, to: file) } }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(try Data(contentsOf: destination) == data)
        try FileManager.default.moveItem(at: destination, to: file)
        #expect(try Data(contentsOf: file) == data)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_VERIFY_TRASH"] == "1" && DistributionMode.current == .direct))
    func `Given our disposable duplicate set, when one copy goes to Finder Trash, then the kept copy survives and the extra copy restores`() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "StorageFix-DuplicateTrash-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("Disposable duplicate test".utf8)
        try data.write(to: root.appending(path: "StorageFix-\(UUID().uuidString)-a.dat"))
        try data.write(to: root.appending(path: "StorageFix-\(UUID().uuidString)-b.dat"))
        let service = FileSystemDuplicateService(roots: [root])
        let group = try #require(try await service.scan().first), copy = try #require(group.duplicates.first)
        let source = URL(fileURLWithPath: copy.path)
        let trash = try FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: source, create: true)
        let destination = trash.appending(path: source.lastPathComponent)
        try await service.remove(paths: [copy.path])
        defer { if FileManager.default.fileExists(atPath: destination.path) { try? FileManager.default.moveItem(at: destination, to: source) } }
        #expect(try Data(contentsOf: URL(fileURLWithPath: group.original.path)) == data)
        #expect(try Data(contentsOf: destination) == data)
        try FileManager.default.moveItem(at: destination, to: source)
        #expect(try Data(contentsOf: source) == data)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORAGEFIX_VERIFY_TRASH"] == "1" && DistributionMode.current == .direct))
    func `Given our disposable app and separate documents, when the reviewed bundle goes to Trash, then documents stay and the bundle restores`() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "StorageFix-AppTrash-\(UUID().uuidString)").resolvingSymlinksInPath()
        let app = root.appending(path: "StorageFix-\(UUID().uuidString).app"), contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = ["CFBundleIdentifier": "com.storagefix.disposable", "CFBundleName": "Disposable test", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appending(path: "Info.plist"))
        let payload = Data("Disposable application".utf8), document = root.appending(path: "keep.txt")
        try payload.write(to: contents.appending(path: "payload")); try payload.write(to: document)
        let capture = TrashDestination()
        let service = ApplicationService(roots: [root], runningPaths: { [] }, trash: { source in
            var destination: NSURL?; try FileManager.default.trashItem(at: source, resultingItemURL: &destination)
            if let destination { await capture.set(destination as URL) }
        })
        let reviewed = try #require(try await service.scan().first)
        try await service.moveToTrash(reviewed)
        let destination = try #require(await capture.url)
        defer { if FileManager.default.fileExists(atPath: destination.path) { try? FileManager.default.moveItem(at: destination, to: app) } }
        #expect(!FileManager.default.fileExists(atPath: app.path))
        #expect(try Data(contentsOf: document) == payload)
        try FileManager.default.moveItem(at: destination, to: app)
        #expect(try Data(contentsOf: contents.appending(path: "payload")) == payload)
    }

}
private actor TrashDestination {
    var url: URL?
    func set(_ value: URL) { url = value }
}
