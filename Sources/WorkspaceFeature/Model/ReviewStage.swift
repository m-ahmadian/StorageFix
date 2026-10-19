import Foundation

/// Runs one Quick Review stage so that cancelling returns control immediately, even while the stage is stuck in a
/// filesystem call (for example waiting on a macOS folder-access prompt). The abandoned stage is cancelled and may
/// finish later on its own; its late result is ignored by the review.
enum ReviewStage {
    /// Returns true when the stage finished, false when the review was cancelled first.
    @MainActor static func run(_ work: @escaping @MainActor () async -> Void) async -> Bool {
        let gate = StageGate()
        let stage = Task { @MainActor in await work(); gate.finish(true) }
        return await withTaskCancellationHandler {
            await gate.wait()
        } onCancel: {
            stage.cancel()
            gate.finish(false)
        }
    }
}

/// Resumes its waiter exactly once with the first outcome reported.
final class StageGate: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: Bool?
    private var waiter: CheckedContinuation<Bool, Never>?

    func wait() async -> Bool {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let outcome { lock.unlock(); continuation.resume(returning: outcome); return }
            waiter = continuation
            lock.unlock()
        }
    }

    func finish(_ value: Bool) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        outcome = value
        let continuation = waiter; waiter = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
