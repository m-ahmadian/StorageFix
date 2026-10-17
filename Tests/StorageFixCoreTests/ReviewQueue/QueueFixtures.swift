import Foundation
import StorageFixCore

@MainActor enum QueueFixtures {
    static let root = URL(fileURLWithPath: "/fixture")
    static func file(_ name: String, bytes: Int64 = 100) -> DuplicateFile {
        DuplicateFile(path: "/fixture/\(name)", bytes: bytes, modifiedAt: Date(timeIntervalSince1970: 100), fileIdentity: "device:\(name)")
    }
    static func scan(_ files: [DuplicateFile], options: InventoryOptions = InventoryOptions(), cancelled: Bool = false,
                     readOnly: Bool = false) -> InventoryScan {
        InventoryScan(sessionID: UUID(), root: root, options: options, files: files, wasCancelled: cancelled,
            volume: InventoryVolume(name: "Fixture", capacityBytes: 1000, availableBytes: 500, isReadOnly: readOnly))
    }
    static func queue(operations: RecordingQueueOperations = RecordingQueueOperations(), limit: Int = 100) -> ReviewQueue {
        ReviewQueue(policy: ReviewFilePolicy(protectedRoots: [root.appending(path: "protected")]), operations: operations, itemLimit: limit)
    }
}

actor RecordingQueueOperations: ReviewFileOperationsProtocol {
    private(set) var moved: [String] = []
    private(set) var validated: [String] = []
    private(set) var constraintCalls = 0
    let invalidPath: String?
    let failedTrash: String?
    let pauses: Bool
    private var started = false
    private var observer: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    init(invalidPath: String? = nil, failedTrash: String? = nil, pauses: Bool = false) {
        self.invalidPath = invalidPath; self.failedTrash = failedTrash; self.pauses = pauses
    }
    func validate(_ item: ReviewQueueItem) async throws {
        validated.append(item.id)
        if pauses && !started {
            started = true; observer?.resume(); observer = nil
            await withCheckedContinuation { waiter = $0 }
        }
        if item.id == invalidPath { throw ReviewQueueError.changed(item.id) }
    }
    func validate(_ protection: ReviewDuplicateProtection, selected: Set<String>, preflight: Bool) throws {
        constraintCalls += 1
        if preflight && protection.members.contains(where: { moved.contains($0.path) }) {
            throw ReviewQueueError.changed("Already moved group member")
        }
        if selected.contains(protection.kept.path) { throw ReviewQueueError.keptCopy }
    }
    func moveToTrash(_ item: ReviewQueueItem, protections: [ReviewDuplicateProtection]) throws {
        for protection in protections { try validate(protection, selected: [item.id], preflight: false) }
        if item.id == failedTrash { throw ReviewQueueError.inaccessible(item.id) }
        moved.append(item.id)
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() { waiter?.resume(); waiter = nil }
}
