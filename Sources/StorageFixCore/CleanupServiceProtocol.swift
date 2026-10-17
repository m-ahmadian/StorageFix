import Foundation

public protocol CleanupServiceProtocol: Sendable {
    func scan() async throws -> CleanupReport
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport
    /// Folder the person must grant before scanning, or nil when no grant is needed.
    var requiredFolder: URL? { get }
    /// Accepts a granted folder; throws when it is not the required one.
    func grantAccess(to folder: URL) async throws
    var hasAccess: Bool { get async }
}

public extension CleanupServiceProtocol {
    var requiredFolder: URL? { nil }
    func grantAccess(to folder: URL) async throws {}
    var hasAccess: Bool { get async { true } }
}
