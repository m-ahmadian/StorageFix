import Darwin
import Foundation

/// Metadata only. The visitor returns false to prune a directory, without entering it.
public protocol InventoryMetadataSource: Sendable {
    func walk(root: URL, visit: (InventoryMetadata) throws -> Bool,
              issue: @escaping (InventoryIssue) -> Void) throws
    func volume(at root: URL) -> InventoryVolume?
}

public struct InventoryMetadata: Sendable {
    public let path: String
    public var isDirectory = false
    public var isRegularFile = false
    public var isSymbolicLink = false
    public var isHidden = false
    public var isPackage = false
    public var isCloudPlaceholder = false
    public var bytes: Int64?
    public var allocatedBytes: Int64?
    public var modifiedAt: Date?
    public var identity: String?
    public var linkCount = 1
    public var mayShareContent: Bool?
    public init(path: String) { self.path = path }
}

public struct LocalInventoryMetadataSource: InventoryMetadataSource {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey, .isPackageKey,
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .fileSizeKey,
        .totalFileAllocatedSizeKey, .contentModificationDateKey, .mayShareFileContentKey
    ]
    public init() {}

    public func walk(root: URL, visit: (InventoryMetadata) throws -> Bool,
                     issue: @escaping (InventoryIssue) -> Void) throws {
        let manager = FileManager.default
        let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
        guard rootValues?.isDirectory == true, rootValues?.isSymbolicLink != true else {
            throw FileReviewError.unavailableFolder(root.path)
        }
        if try isDataless(root) { issue(InventoryIssue(path: root.path, reason: .cloudPlaceholder)); return }
        if rootValues?.isPackage == true {
            var package = InventoryMetadata(path: root.standardizedFileURL.path)
            package.isDirectory = true; package.isPackage = true
            guard try visit(package) else { return }
        }
        guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [], errorHandler: { url, error in issue(Self.issue(url, error: error)); return true }) else {
            throw FileReviewError.unavailableFolder(root.path)
        }
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            do {
                let shouldPrune = try autoreleasepool {
                    let item = try metadata(at: url)
                    let descend = try visit(item)
                    return item.isDirectory && !descend
                }
                if shouldPrune { enumerator.skipDescendants() }
            } catch is CancellationError { throw CancellationError() }
            catch {
                issue(Self.issue(url, error: error))
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { enumerator.skipDescendants() }
            }
        }
    }

    public func volume(at root: URL) -> InventoryVolume? {
        guard let values = try? root.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey, .volumeIsReadOnlyKey, .volumeUUIDStringKey]) else { return nil }
        return InventoryVolume(name: values.volumeName, capacityBytes: values.volumeTotalCapacity.map(Int64.init),
            availableBytes: values.volumeAvailableCapacity.map(Int64.init), isReadOnly: values.volumeIsReadOnly,
            identifier: values.volumeUUIDString)
    }

    private func metadata(at url: URL) throws -> InventoryMetadata {
        if try isDataless(url) {
            var placeholder = InventoryMetadata(path: url.standardizedFileURL.path)
            placeholder.isCloudPlaceholder = true
            return placeholder
        }
        let values = try url.resourceValues(forKeys: Self.keys)
        var item = InventoryMetadata(path: url.standardizedFileURL.path)
        item.isDirectory = values.isDirectory == true; item.isRegularFile = values.isRegularFile == true
        item.isSymbolicLink = values.isSymbolicLink == true; item.isHidden = values.isHidden == true
        item.isPackage = values.isPackage == true
        item.isCloudPlaceholder = values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current
            && values.ubiquitousItemDownloadingStatus != .downloaded
        item.bytes = values.fileSize.map(Int64.init)
        item.allocatedBytes = values.totalFileAllocatedSize.map(Int64.init)
        item.modifiedAt = values.contentModificationDate
        item.mayShareContent = values.mayShareFileContent
        if item.isRegularFile && !item.isSymbolicLink && !item.isCloudPlaceholder {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let device = attributes[.systemNumber], let inode = attributes[.systemFileNumber] {
                item.identity = "\(device):\(inode)"
            }
            item.linkCount = (attributes[.referenceCount] as? NSNumber)?.intValue ?? 1
            guard (attributes[.size] as? NSNumber)?.int64Value == item.bytes,
                  attributes[.modificationDate] as? Date == item.modifiedAt else {
                throw FileReviewError.changedFile(url.path)
            }
        }
        return item
    }

    private func isDataless(_ url: URL) throws -> Bool {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return attributes.st_flags & UInt32(SF_DATALESS) != 0
    }

    private static func issue(_ url: URL, error: Error) -> InventoryIssue {
        if case FileReviewError.changedFile = error { return InventoryIssue(path: url.path, reason: .changed) }
        let failure = error as NSError
        let missing = failure.domain == NSPOSIXErrorDomain ? failure.code == Int(ENOENT) : failure.code == NSFileNoSuchFileError
        let reason: InventoryIssueReason = missing ? .disappeared : .inaccessible
        return InventoryIssue(path: url.path, reason: reason)
    }
}
