import Foundation

public struct ReviewFilePolicy: ReviewFilePolicyProtocol {
    public static let systemRoots = ["/System", "/bin", "/sbin", "/usr", "/Library", "/Applications",
                                     "/private/etc", "/private/var/db", "/private/var/root", "/private/var/vm"]
    private static let libraryDirectoryName = "library"
    private let protectedRoots: [String]
    private static let packageExtensions: Set<String> = ["app", "bundle", "framework", "plugin", "kext", "pkg", "photoslibrary", "photolibrary"]
    public init(protectedRoots: [URL]) { self.protectedRoots = protectedRoots.map { $0.standardizedFileURL.path.lowercased() } }

    public func validate(_ file: DuplicateFile, root: URL) throws {
        guard file.modifiedAt != nil, let identity = file.fileIdentity, !identity.isEmpty, file.bytes >= 0 else {
            throw ReviewQueueError.unavailableMetadata
        }
        guard !file.isSharedLink else { throw ReviewQueueError.sharedLink }
        let url = URL(fileURLWithPath: file.path)
        let normalized = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard file.path == normalized, normalized.hasPrefix(prefix) else { throw ReviewQueueError.unreviewed }
        let comparablePath = normalized.lowercased()
        guard !protectedRoots.contains(where: { comparablePath == $0 || comparablePath.hasPrefix($0 + "/") }),
              !url.pathComponents.contains(where: { $0.lowercased() == Self.libraryDirectoryName }),
              !url.pathComponents.contains(where: { $0.hasPrefix(".") || Self.packageExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }) else {
            throw ReviewQueueError.protectedPath
        }
    }
}
