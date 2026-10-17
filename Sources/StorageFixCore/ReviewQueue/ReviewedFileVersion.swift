import Darwin
import Foundation

struct ReviewedFileVersion: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let links: nlink_t
    let flags: UInt32

    private init(_ info: stat) {
        device = info.st_dev; inode = info.st_ino; size = info.st_size
        modifiedSeconds = info.st_mtimespec.tv_sec; modifiedNanoseconds = info.st_mtimespec.tv_nsec
        links = info.st_nlink; flags = info.st_flags
    }
    static func read(descriptor: Int32) throws -> ReviewedFileVersion {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              info.st_nlink == 1, info.st_flags & UInt32(SF_DATALESS) == 0 else { throw ReviewQueueError.unavailableMetadata }
        return ReviewedFileVersion(info)
    }

    static func read(_ file: DuplicateFile, root: URL) throws -> ReviewedFileVersion {
        let url = URL(fileURLWithPath: file.path)
        guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL else { throw ReviewQueueError.changed(file.path) }
        try checkAncestors(url, root: root)
        var info = stat()
        guard lstat(file.path, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              info.st_nlink == 1, info.st_flags & UInt32(SF_DATALESS) == 0 else { throw ReviewQueueError.changed(file.path) }
        let identity = "\(info.st_dev):\(info.st_ino)"
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .volumeIsReadOnlyKey])
        guard info.st_size == file.bytes, identity == file.fileIdentity,
              values.contentModificationDate == file.modifiedAt else { throw ReviewQueueError.changed(file.path) }
        guard values.volumeIsReadOnly != true,
              FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else { throw ReviewQueueError.inaccessible(file.path) }
        return ReviewedFileVersion(info)
    }

    private static func checkAncestors(_ url: URL, root: URL) throws {
        var current = url.deletingLastPathComponent()
        let rootPath = root.standardizedFileURL.path
        while current.path == rootPath || current.path.hasPrefix(rootPath == "/" ? "/" : rootPath + "/") {
            let values = try current.resourceValues(forKeys: [.isPackageKey, .isSymbolicLinkKey])
            guard values.isPackage != true, values.isSymbolicLink != true else { throw ReviewQueueError.protectedPath }
            if current.path == rootPath { return }
            current = current.deletingLastPathComponent()
        }
        throw ReviewQueueError.unreviewed
    }
}
