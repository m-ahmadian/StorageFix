import Foundation

public protocol FileBrowserServiceProtocol: FileInventoryServiceProtocol {
    func moveToTrash(paths: Set<String>) async throws
}

public actor FileBrowserService: FileBrowserServiceProtocol {
    private var reviewed: [String: DuplicateFile] = [:]
    private var activeSession: UUID?
    private let inventoryService: any FileInventoryServiceProtocol
    private let trash: @Sendable (URL) async throws -> Void
    public init(inventoryService: any FileInventoryServiceProtocol = FileInventoryService(),
                trash: @escaping @Sendable (URL) async throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
        self.inventoryService = inventoryService; self.trash = trash
    }
    public func scan(in root: URL) async throws -> [DuplicateFile] {
        let result = try await inventory(in: root, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        try Task.checkCancellation()
        return result.files.filter { !$0.isSharedLink }
    }
    public func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                          progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        reviewed = [:]; activeSession = sessionID
        let result = try await inventoryService.inventory(in: root, options: options, sessionID: sessionID, progress: progress)
        guard activeSession == sessionID, result.sessionID == sessionID else { throw CancellationError() }
        // Inspection options never grant deletion permission for hidden/package contents.
        if !result.wasCancelled && !Task.isCancelled && result.volume?.isReadOnly != true && options == InventoryOptions() {
            reviewed = Dictionary(uniqueKeysWithValues: result.files.filter { !$0.isSharedLink }.map { ($0.path, $0) })
        }
        return result
    }
    public func moveToTrash(paths: Set<String>) async throws {
        guard paths.allSatisfy({ reviewed[$0] != nil }) else { throw FileBrowserError.unreviewed }
        for path in paths.sorted() {
            guard let file = reviewed[path], let date = file.modifiedAt, let identity = file.fileIdentity else { throw FileBrowserError.unreviewed }
            let url = URL(fileURLWithPath: path)
            guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL else { throw FileBrowserError.changed(path) }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let currentIdentity = "\(attributes[.systemNumber] ?? ""):\(attributes[.systemFileNumber] ?? "")"
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  Int64(values.fileSize ?? -1) == file.bytes, values.contentModificationDate == date,
                  currentIdentity == identity, ((attributes[.referenceCount] as? NSNumber)?.intValue ?? 1) <= 1 else { throw FileBrowserError.changed(path) }
        }
        for path in paths.sorted() { try await trash(URL(fileURLWithPath: path)) }
        reviewed = [:]
    }
}

public enum FileBrowserError: Error, LocalizedError {
    case unreviewed, changed(String)
    public var errorDescription: String? {
        switch self {
        case .unreviewed: "Scan again before moving reviewed files to Trash."
        case .changed(let path): "This file changed since the scan: \(path). Scan again to review the current version."
        }
    }
}
