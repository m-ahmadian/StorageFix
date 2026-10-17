import AppKit
import CryptoKit
import Foundation

public struct InstalledApplication: Identifiable, Equatable, Sendable {
    public let path: String
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let bytes: Int64
    public let snapshot: String?
    public var id: String { path }
    public init(path: String, name: String, bundleIdentifier: String, version: String, bytes: Int64, snapshot: String? = nil) {
        self.path = path; self.name = name; self.bundleIdentifier = bundleIdentifier; self.version = version; self.bytes = bytes; self.snapshot = snapshot
    }
}
public protocol ApplicationServiceProtocol: Sendable {
    func scan() async throws -> [InstalledApplication]
    func moveToTrash(_ app: InstalledApplication) async throws
}
public actor ApplicationService: ApplicationServiceProtocol {
    private let permitsRemoval: Bool
    private let roots: [URL]
    private var reviewed: [String: InstalledApplication] = [:]
    private let runningPaths: @Sendable () async -> [String]
    private let trash: @Sendable (URL) async throws -> Void
    public init(roots: [URL], permitsRemoval: Bool = true, runningPaths: @escaping @Sendable () async -> [String] = {
        await MainActor.run { NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path } }
    }, trash: @escaping @Sendable (URL) async throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
        self.permitsRemoval = permitsRemoval && DistributionMode.current != .appStore
        self.roots = roots.map { $0.resolvingSymlinksInPath() }; self.runningPaths = runningPaths; self.trash = trash
    }
    public func scan() async throws -> [InstalledApplication] {
        reviewed = [:]
        let roots = roots
        let task = Task.detached { try Self.applications(in: roots) }
        let apps = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        reviewed = Dictionary(uniqueKeysWithValues: apps.map { ($0.path, $0) })
        return apps
    }
    public func moveToTrash(_ app: InstalledApplication) async throws {
        guard permitsRemoval else { throw ApplicationReviewError.protectedApp }
        guard reviewed[app.path] == app else { throw ApplicationReviewError.unreviewed }
        let url = URL(fileURLWithPath: app.path)
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let systemRoot = URL(fileURLWithPath: "/System").standardizedFileURL.path + "/"
        guard canonical == url.standardizedFileURL, !canonical.path.hasPrefix(systemRoot),
              roots.contains(where: { canonical.path.hasPrefix($0.standardizedFileURL.path + "/") }),
              url.pathExtension == "app" else { throw ApplicationReviewError.protectedApp }
        let running = await runningPaths().contains(canonical.path)
        guard !running else { throw ApplicationReviewError.running }
        let measurement = try Self.measure(url)
        guard Bundle(url: url)?.bundleIdentifier == app.bundleIdentifier,
              measurement.bytes == app.bytes, measurement.snapshot == app.snapshot else { throw ApplicationReviewError.changed }
        try await trash(url)
        reviewed[app.path] = nil
    }
    private static func applications(in roots: [URL]) throws -> [InstalledApplication] {
        var apps: [InstalledApplication] = []
        var visited: Set<String> = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            var error: Error?
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, failure in error = failure; return false }) else { throw FileReviewError.unavailableFolder(root.path) }
            for case let url as URL in enumerator {
                try Task.checkCancellation()
                guard url.pathExtension == "app", visited.insert(url.path).inserted else { continue }
                let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true, let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
                let measurement = try measure(url)
                apps.append(InstalledApplication(path: url.path,
                    name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent,
                    bundleIdentifier: identifier, version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—", bytes: measurement.bytes, snapshot: measurement.snapshot))
            }
            if let error { throw error }
        }
        return apps.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
    }
    private static func measure(_ root: URL) throws -> (bytes: Int64, snapshot: String) {
        var error: Error?
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey],
            options: [], errorHandler: { _, failure in error = failure; return false }) else { throw FileReviewError.unavailableFolder(root.path) }
        var bytes: Int64 = 0
        var signatures: [String] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey])
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            // Track every entry, including symlinks, so newly added links also invalidate a review.
            signatures.append("\(url.path)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values.fileSize ?? 0)|\(attributes[.systemFileNumber] ?? "")")
            if values.isRegularFile == true, values.isSymbolicLink != true { bytes += Int64(values.fileAllocatedSize ?? 0) }
        }
        if let error { throw error }
        let digest = SHA256.hash(data: Data(signatures.sorted().joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
        return (bytes, digest)
    }
}
public enum ApplicationReviewError: Error, LocalizedError {
    case unreviewed, protectedApp, running, changed
    public var errorDescription: String? {
        switch self {
        case .unreviewed: "Scan again before removing an application."
        case .protectedApp: "This application is outside the reviewed Applications folders or is protected by macOS."
        case .running: "Quit this application first, then try again."
        case .changed: "The application changed since the scan. Scan again before removing it."
        }
    }
}
