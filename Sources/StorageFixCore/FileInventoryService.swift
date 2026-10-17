import Foundation

public actor FileInventoryService: FileInventoryServiceProtocol {
    private let scanner: InventoryScanner
    public init(source: any InventoryMetadataSource = LocalInventoryMetadataSource()) {
        scanner = InventoryScanner(source: source)
    }

    public func scan(in root: URL) async throws -> [DuplicateFile] {
        let result = try await inventory(in: root, options: InventoryOptions(), sessionID: UUID(), progress: { _ in })
        try Task.checkCancellation()
        return result.files
    }

    public func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                          progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        try Task.checkCancellation()
        let scanner = scanner
        let worker = Task.detached { try scanner.scan(root: root, options: options, sessionID: sessionID, progress: progress) }
        let result = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: { worker.cancel() }
        return Task.isCancelled ? result.cancelled() : result
    }
}
