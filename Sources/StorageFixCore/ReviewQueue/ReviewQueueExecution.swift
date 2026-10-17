import Foundation

extension ReviewQueue {
    public func execute(expectedRevision: UUID) async throws {
        guard !snapshot.isExecuting else { throw ReviewQueueError.busy }
        guard snapshot.revision == expectedRevision, !entries.isEmpty else { throw ReviewQueueError.reviewChanged }
        let batch = snapshot.items
        let constraints = protections.filter { $0.members.contains { entries[$0.path] != nil } }
        let selected = Set(batch.map(\.id))
        let blockers = snapshot.blockers
        publish(executing: true)
        let outcomes: [ReviewQueueOutcome]
        var freeSpace: FreeSpaceMeasurement?
        do {
            guard blockers.isEmpty else { throw ReviewQueueError.rescanRequired }
            try await preflight(batch, constraints: constraints, selected: selected)
            let before = beginFreeSpaceMeasurement(batch)
            outcomes = await move(batch, constraints: constraints)
            freeSpace = before.map { completeFreeSpaceMeasurement($0) }
        } catch {
            let status: ReviewQueueItemStatus = error is CancellationError ? .cancelled : .blocked
            let message = error is CancellationError ? "Nothing moved. Operation cancelled before mutation." : "Nothing moved. \(error.localizedDescription)"
            outcomes = batch.map { outcome($0, status: status, message: message) }
        }
        finish(batch, outcomes: outcomes, freeSpace: freeSpace)
    }

    public func remeasureFreeSpace() {
        guard !snapshot.isExecuting, let run = snapshot.lastRun, let measurement = run.freeSpace,
              let root = measurementRoot, let freeSpaceProbe else { return }
        let updated = measurement.remeasured(afterBytes: freeSpaceProbe.availableBytes(at: root), at: Date())
        snapshot = ReviewQueueSnapshot(revision: snapshot.revision, items: snapshot.items, blockers: snapshot.blockers,
            completedCount: snapshot.completedCount, lastRun: run.replacingFreeSpace(updated))
    }

    private func beginFreeSpaceMeasurement(_ batch: [ReviewQueueItem]) -> FreeSpaceMeasurement? {
        measurementRoot = nil
        guard let freeSpaceProbe else { return nil }
        switch freeSpaceProbe.target(for: batch.map(\.root)) {
        case .failure(let error): return .unavailable(error.reason)
        case .success(let root):
            guard let before = freeSpaceProbe.availableBytes(at: root) else { return .unavailable(FreeSpaceProbe.unreadable) }
            measurementRoot = root
            return FreeSpaceMeasurement(beforeBytes: before, afterBytes: nil)
        }
    }

    private func completeFreeSpaceMeasurement(_ measurement: FreeSpaceMeasurement) -> FreeSpaceMeasurement {
        guard let root = measurementRoot, let freeSpaceProbe else { return measurement }
        return measurement.remeasured(afterBytes: freeSpaceProbe.availableBytes(at: root), at: Date())
    }

    private func preflight(_ batch: [ReviewQueueItem], constraints: [ReviewDuplicateProtection], selected: Set<String>) async throws {
        for item in batch {
            try Task.checkCancellation()
            try policy.validate(item.file, root: item.root)
            try await operations.validate(item)
        }
        for protection in constraints {
            try Task.checkCancellation()
            guard !selected.contains(protection.kept.path) else { throw ReviewQueueError.keptCopy }
            try await operations.validate(protection, selected: selected, preflight: true)
        }
    }

    private func move(_ batch: [ReviewQueueItem], constraints: [ReviewDuplicateProtection]) async -> [ReviewQueueOutcome] {
        var results: [ReviewQueueOutcome] = []
        for item in batch {
            if Task.isCancelled {
                results.append(outcome(item, status: .cancelled, message: "Not moved. Operation cancelled."))
                continue
            }
            do {
                let relevant = constraints.filter { $0.members.contains { $0.path == item.id } }
                try Task.checkCancellation()
                try await operations.moveToTrash(item, protections: relevant)
                results.append(outcome(item, status: .moved, message: "Moved to Trash. Restore using Put Back in Finder where available."))
            } catch {
                let status: ReviewQueueItemStatus = error is CancellationError ? .cancelled : .failed
                results.append(outcome(item, status: status, message: "Not confirmed moved. \(error.localizedDescription)"))
            }
            publish(executing: true, completed: results.count)
        }
        return results
    }

    private func outcome(_ item: ReviewQueueItem, status: ReviewQueueItemStatus, message: String) -> ReviewQueueOutcome {
        ReviewQueueOutcome(path: item.id, logicalBytes: item.file.bytes, status: status, message: message)
    }

    private func adjustedProtections(_ values: [ReviewDuplicateProtection.ID: ReviewDuplicateProtection], moved: Set<String>) -> [ReviewDuplicateProtection.ID: ReviewDuplicateProtection] {
        Dictionary(values.values.map { $0.excludingMoved(moved) }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func finish(_ batch: [ReviewQueueItem], outcomes: [ReviewQueueOutcome], freeSpace: FreeSpaceMeasurement?) {
        let moved = Set(outcomes.filter { $0.status == .moved }.map(\.path))
        entries = Dictionary(uniqueKeysWithValues: batch.filter { !moved.contains($0.id) }.map {
            ($0.id, ReviewQueueItem(file: $0.file, root: $0.root, origins: $0.origins, requiresRescan: true))
        })
        pathIndex = QueuePathIndex(paths: Array(entries.keys))
        registrations = [:]
        currentProtections = adjustedProtections(currentProtections, moved: moved)
        frozenProtections = adjustedProtections(frozenProtections, moved: moved)
        let run = ReviewQueueRun(outcomes: outcomes, freeSpace: freeSpace)
        publish(completed: outcomes.count, run: run)
    }
}
