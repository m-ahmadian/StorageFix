import Foundation

public protocol FileInventoryServiceProtocol: Sendable {
    func scan(in root: URL) async throws -> [DuplicateFile]
    func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                   progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan
}

public extension FileInventoryServiceProtocol {
    /// Compatibility for injected array-only sources. Never invents coverage information.
    func inventory(in root: URL, options: InventoryOptions, sessionID: UUID,
                   progress: @escaping @Sendable (InventoryProgress) -> Void) async throws -> InventoryScan {
        let files = try await scan(in: root)
        try Task.checkCancellation()
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var coverage = InventoryCoverage()
        let scoped = files.filter { file in
            let included = URL(fileURLWithPath: file.path).standardizedFileURL.path.hasPrefix(prefix)
            if !included { coverage.record(InventoryIssue(path: file.path, reason: .unsupported)) }
            return included
        }
        return InventoryScan(sessionID: sessionID, root: root, options: options, files: scoped,
            coverage: coverage, coverageAvailable: false)
    }
}
