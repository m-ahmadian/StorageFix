import Foundation
import StorageFixCore

actor MapInventoryFixture: FileInventoryServiceProtocol {
    private(set) var calls = 0

    func scan(in root: URL) async throws -> [DuplicateFile] {
        calls += 1
        return (1...8).map { DuplicateFile(path: "/fixture/item-\($0)", bytes: Int64($0) * 100) }
            + [DuplicateFile(path: "/fixture/nested/a", bytes: 100),
               DuplicateFile(path: "/fixture/nested/b", bytes: 50),
               DuplicateFile(path: "/outside/ignored", bytes: 1_000_000)]
    }
}

struct FailingMapInventory: FileInventoryServiceProtocol {
    func scan(in root: URL) async throws -> [DuplicateFile] {
        throw FileReviewError.unavailableFolder(root.path)
    }
}

actor PausedMapInventory: FileInventoryServiceProtocol {
    private var started = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func scan(in root: URL) async throws -> [DuplicateFile] {
        started = true
        observer?.resume(); observer = nil
        await withCheckedContinuation { waiter = $0 }
        // Deliberately returns after cancellation to test the view model's own check.
        return [DuplicateFile(path: "/fixture/item", bytes: 100)]
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }

    func finish() { waiter?.resume(); waiter = nil }
}
