import Combine
import Foundation

@MainActor public protocol ReviewQueueProtocol: AnyObject, Sendable {
    var snapshot: ReviewQueueSnapshot { get }
    var updates: AnyPublisher<ReviewQueueSnapshot, Never> { get }
    func registerInventory(_ scan: InventoryScan, origin: ReviewOrigin)
    func registerDuplicates(_ groups: [DuplicateGroup], root: URL)
    func add(paths: Set<String>, origin: ReviewOrigin) -> ReviewQueueAddResult
    func remove(path: String)
    func clear()
    func execute(expectedRevision: UUID) async throws
    /// Reads the last operation's volume free space again. Never mutates files.
    func remeasureFreeSpace()
}

public protocol ReviewFilePolicyProtocol: Sendable {
    func validate(_ file: DuplicateFile, root: URL) throws
}

public protocol ReviewFileOperationsProtocol: Sendable {
    func validate(_ item: ReviewQueueItem) async throws
    func validate(_ protection: ReviewDuplicateProtection, selected: Set<String>, preflight: Bool) async throws
    /// Revalidates immediately before the native Trash operation. Never permanently deletes.
    func moveToTrash(_ item: ReviewQueueItem, protections: [ReviewDuplicateProtection]) async throws
}
