import Combine

public extension ReviewQueueProtocol {
    var finishedRuns: AnyPublisher<ReviewQueueRun, Never> {
        updates.compactMap(\.lastRun).removeDuplicates { $0.id == $1.id }.eraseToAnyPublisher()
    }
}
