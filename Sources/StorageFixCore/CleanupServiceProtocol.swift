public protocol CleanupServiceProtocol: Sendable {
    func scan() async throws -> CleanupReport
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport
}
