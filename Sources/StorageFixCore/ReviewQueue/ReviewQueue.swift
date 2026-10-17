import Combine
import Foundation

@MainActor public final class ReviewQueue: ReviewQueueProtocol {
    public static let maximumItemCount = 10_000
    @Published public internal(set) var snapshot = ReviewQueueSnapshot()
    public var updates: AnyPublisher<ReviewQueueSnapshot, Never> { $snapshot.eraseToAnyPublisher() }
    let policy: any ReviewFilePolicyProtocol
    let operations: any ReviewFileOperationsProtocol
    let itemLimit: Int
    let freeSpaceProbe: FreeSpaceProbe?
    var measurementRoot: URL?
    var pathIndex = QueuePathIndex()
    var entries: [String: ReviewQueueItem] = [:]
    var registrations: [ReviewOrigin: QueueRegistration] = [:]
    var currentProtections: [ReviewDuplicateProtection.ID: ReviewDuplicateProtection] = [:]
    var frozenProtections: [ReviewDuplicateProtection.ID: ReviewDuplicateProtection] = [:]

    public init(policy: any ReviewFilePolicyProtocol, operations: any ReviewFileOperationsProtocol,
                itemLimit: Int = ReviewQueue.maximumItemCount, volumes: (any VolumeInformationServiceProtocol)? = nil) {
        self.policy = policy; self.operations = operations; self.itemLimit = max(1, itemLimit)
        freeSpaceProbe = volumes.map { FreeSpaceProbe(volumes: $0) }
    }

    public func registerInventory(_ scan: InventoryScan, origin: ReviewOrigin) {
        guard !snapshot.isExecuting, origin != .duplicates else { return }
        let inspectOnly = scan.wasCancelled || scan.options != InventoryOptions() || scan.volume?.isReadOnly == true
        registrations[origin] = QueueRegistration(root: scan.root, files: scan.files, inspectionOnly: inspectOnly)
    }

    public func registerDuplicates(_ groups: [DuplicateGroup], root: URL) {
        guard !snapshot.isExecuting else { return }
        for protection in protections where protection.members.contains(where: { entries[$0.path] != nil }) {
            frozenProtections[protection.id] = protection
        }
        currentProtections = [:]
        for group in groups {
            let protection = ReviewDuplicateProtection(group: group, root: root)
            currentProtections[protection.id] = protection
        }
        registrations[.duplicates] = QueueRegistration(root: root, files: groups.flatMap { [$0.original] + $0.duplicates })
        publish()
    }

    public func add(paths: Set<String>, origin: ReviewOrigin) -> ReviewQueueAddResult {
        guard !snapshot.isExecuting else {
            return ReviewQueueAddResult(addedCount: 0, existingCount: 0,
                rejections: Dictionary(uniqueKeysWithValues: paths.map { ($0, ReviewQueueError.busy.localizedDescription) }))
        }
        let keptPaths = Set(protections.map { $0.kept.path })
        var added = 0, existing = 0
        var rejected: [String: String] = [:]
        for path in paths.sorted() {
            do {
                if try add(path: path, origin: origin, keptPaths: keptPaths) { added += 1 } else { existing += 1 }
            } catch { rejected[path] = error.localizedDescription }
        }
        publish()
        return ReviewQueueAddResult(addedCount: added, existingCount: existing, rejections: rejected)
    }

    public func remove(path: String) {
        guard !snapshot.isExecuting else { return }
        entries.removeValue(forKey: path)
        pathIndex = QueuePathIndex(paths: Array(entries.keys))
        frozenProtections = frozenProtections.filter { $0.value.members.contains { entries[$0.path] != nil } }
        publish()
    }
    public func clear() {
        guard !snapshot.isExecuting else { return }
        entries = [:]; pathIndex = QueuePathIndex(); frozenProtections = [:]; publish()
    }

    var protections: [ReviewDuplicateProtection] {
        let merged = frozenProtections.merging(currentProtections, uniquingKeysWith: { _, latest in latest })
        return merged.values.sorted { left, right in
            if left.digest != right.digest { return left.digest < right.digest }
            return left.id.paths.lexicographicallyPrecedes(right.id.paths)
        }
    }
    func publish(executing: Bool = false, completed: Int = 0, run: ReviewQueueRun? = nil) {
        var blockers: [String: String] = [:]
        for item in entries.values where item.requiresRescan { blockers[item.id] = ReviewQueueError.rescanRequired.localizedDescription }
        for protection in protections where entries[protection.kept.path] != nil {
            blockers[protection.kept.path] = ReviewQueueError.keptCopy.localizedDescription
        }
        snapshot = ReviewQueueSnapshot(items: entries.values.sorted { $0.id < $1.id }, blockers: blockers,
            isExecuting: executing, completedCount: completed, lastRun: run ?? snapshot.lastRun)
    }

    private func add(path: String, origin: ReviewOrigin, keptPaths: Set<String>) throws -> Bool {
        guard !snapshot.isExecuting else { throw ReviewQueueError.busy }
        guard let registration = registrations[origin], let file = registration.files[path] else { throw ReviewQueueError.unreviewed }
        guard !registration.inspectionOnly else { throw ReviewQueueError.inspectionOnly }
        try policy.validate(file, root: registration.root)
        guard !keptPaths.contains(path) else { throw ReviewQueueError.keptCopy }
        if let existing = entries[path] {
            guard existing.file == file, !existing.requiresRescan else { throw ReviewQueueError.conflictingVersion }
            entries[path] = ReviewQueueItem(file: file, root: existing.root, origins: existing.origins.union([origin]))
            return false
        }
        guard !pathIndex.overlaps(path) else { throw ReviewQueueError.overlap }
        guard entries.count < itemLimit else { throw ReviewQueueError.capacity }
        entries[path] = ReviewQueueItem(file: file, root: registration.root, origins: [origin])
        pathIndex.insert(path)
        return true
    }
}

struct QueueRegistration {
    let root: URL
    let files: [String: DuplicateFile]
    let inspectionOnly: Bool
    init(root: URL, files: [DuplicateFile], inspectionOnly: Bool = false) {
        self.root = root; self.inspectionOnly = inspectionOnly
        self.files = Dictionary(files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
