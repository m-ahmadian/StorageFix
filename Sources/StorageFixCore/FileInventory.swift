import Foundation

/// Reads visible regular files without following symbolic links or entering app bundles.
public enum FileInventory {
    public static func files(in roots: [URL]) throws -> [DuplicateFile] {
        let scanner = InventoryScanner(source: LocalInventoryMetadataSource())
        var paths: Set<String> = []
        var files: [DuplicateFile] = []
        for root in roots {
            let result = try scanner.scan(root: root, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
            try Task.checkCancellation()
            // Array-only destructive workflows must fail closed on incomplete coverage.
            guard !result.coverage.hasReadErrors else { throw FileReviewError.unavailableFolder(root.path) }
            for file in result.files where !file.isSharedLink {
                if paths.insert(file.path).inserted { files.append(file) }
            }
        }
        return files.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
    }
}

public enum FileReviewError: Error, LocalizedError {
    case unavailableFolder(String)
    case changedFile(String)
    case unreviewedFile
    public var errorDescription: String? {
        switch self {
        case .unavailableFolder(let path): "Cannot read \(path). Choose an accessible folder or allow StorageFix access in System Settings → Privacy & Security."
        case .changedFile(let path): "A file changed since the scan: \(path). Scan again before moving copies to Trash."
        case .unreviewedFile: "Only copies from the latest scan can be moved to Trash. Keep at least one file in every set."
        }
    }
}
