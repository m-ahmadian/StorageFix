import Foundation

public protocol DuplicateServiceProtocol: Sendable {
    func scan() async throws -> [DuplicateGroup]
    func scan(in root: URL?) async throws -> [DuplicateGroup]
    func remove(paths: Set<String>) async throws
    func reveal(path: String)
}
public extension DuplicateServiceProtocol {
    func scan(in root: URL?) async throws -> [DuplicateGroup] { try await scan() }
}
