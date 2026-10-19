import Foundation

/// How far a duplicate scan has come: listing files first, then comparing same-size candidates.
public struct DuplicateScanProgress: Equatable, Sendable {
    public enum Phase: Sendable { case listing, comparing }
    public let phase: Phase
    public let completed: Int
    public let total: Int
    public init(phase: Phase, completed: Int, total: Int) { self.phase = phase; self.completed = completed; self.total = total }
    public var fraction: Double? { phase == .comparing && total > 0 ? min(1, Double(completed) / Double(total)) : nil }
}

public protocol DuplicateServiceProtocol: Sendable {
    func scan() async throws -> [DuplicateGroup]
    func scan(in root: URL?) async throws -> [DuplicateGroup]
    func scan(in root: URL?, progress: @escaping @Sendable (DuplicateScanProgress) -> Void) async throws -> [DuplicateGroup]
    func remove(paths: Set<String>) async throws
    func reveal(path: String)
}
public extension DuplicateServiceProtocol {
    func scan(in root: URL?) async throws -> [DuplicateGroup] { try await scan() }
    func scan(in root: URL?, progress: @escaping @Sendable (DuplicateScanProgress) -> Void) async throws -> [DuplicateGroup] {
        try await scan(in: root)
    }
}
