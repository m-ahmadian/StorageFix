import Foundation
import StorageFixCore

struct QueueFeatureFiles: FileBrowserServiceProtocol, DuplicateServiceProtocol {
    let root = URL(fileURLWithPath: "/fixture")
    var files: [DuplicateFile] {
        ["a", "b"].map { DuplicateFile(path: "/fixture/\($0)", bytes: 100_000_000,
            modifiedAt: Date(timeIntervalSince1970: 100), fileIdentity: "device:\($0)") }
    }
    func scan(in root: URL) async throws -> [DuplicateFile] { files }
    func scan() async throws -> [DuplicateGroup] { [DuplicateGroup(id: "digest", original: files[0], duplicates: [files[1]])] }
    func moveToTrash(paths: Set<String>) async throws { throw ReviewQueueError.unreviewed }
    func remove(paths: Set<String>) async throws { throw ReviewQueueError.unreviewed }
    func reveal(path: String) {}
}

actor QueueFeatureOperations: ReviewFileOperationsProtocol {
    let fail: Bool
    let pause: Bool
    private(set) var moves: [String] = []
    private var started = false
    private var observer: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    init(fail: Bool = false, pause: Bool = false) { self.fail = fail; self.pause = pause }
    func validate(_ item: ReviewQueueItem) async throws {
        if pause && !started {
            started = true; observer?.resume(); observer = nil
            await withCheckedContinuation { waiter = $0 }
        }
        if fail { throw ReviewQueueError.changed(item.id) }
    }
    func validate(_ protection: ReviewDuplicateProtection, selected: Set<String>, preflight: Bool) throws {}
    func moveToTrash(_ item: ReviewQueueItem, protections: [ReviewDuplicateProtection]) { moves.append(item.id) }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() { waiter?.resume(); waiter = nil }
}

@MainActor func featureQueue(operations: QueueFeatureOperations = QueueFeatureOperations()) -> ReviewQueue {
    ReviewQueue(policy: ReviewFilePolicy(protectedRoots: []), operations: operations)
}
