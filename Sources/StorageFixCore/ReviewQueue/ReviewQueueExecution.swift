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
        do {
            guard blockers.isEmpty else { throw ReviewQueueError.rescanRequired }
            try await preflight(batch, constraints: constraints, selected: selected)
            outcomes = await move(batch, constraints: constraints)
        } catch {
            let status: ReviewQueueItemStatus = error is CancellationError ? .cancelled : .blocked
            let message = error is CancellationError ? "Nothing moved. Operation cancelled before mutation." : "Nothing moved. \(error.localizedDescription)"
            outcomes = batch.map { outcome($0, status: status, message: message) }
        }
        finish(batch, outcomes: outcomes)
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

    private func finish(_ batch: [ReviewQueueItem], outcomes: [ReviewQueueOutcome]) {
        let moved = Set(outcomes.filter { $0.status == .moved }.map(\.path))
        entries = Dictionary(uniqueKeysWithValues: batch.filter { !moved.contains($0.id) }.map {
            ($0.id, ReviewQueueItem(file: $0.file, root: $0.root, origins: $0.origins, requiresRescan: true))
        })
        pathIndex = QueuePathIndex(paths: Array(entries.keys))
        registrations = [:]
        currentProtections = adjustedProtections(currentProtections, moved: moved)
        frozenProtections = adjustedProtections(frozenProtections, moved: moved)
        let run = ReviewQueueRun(outcomes: outcomes)
        publish(completed: outcomes.count, run: run)
    }
}
