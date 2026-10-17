import Combine
import Foundation
import StorageFixCore

@MainActor public final class ReviewQueueViewModel: ObservableObject {
    @Published public private(set) var snapshot: ReviewQueueSnapshot
    @Published public private(set) var message: String?
    @Published public var showsConfirmation = false
    @Published public private(set) var confirmationSnapshot: ReviewQueueSnapshot?
    @Published public internal(set) var reportDocument: QueueReportDocument?
    @Published public internal(set) var reportFormat: QueueReportFormat = .text
    @Published public internal(set) var reportIncludesPaths = false
    @Published public internal(set) var isPreparingReport = false
    @Published public internal(set) var reportError: String?
    let reportService: (any QueueReportServiceProtocol)?
    var reportGeneration: UUID?
    private let queue: any ReviewQueueProtocol
    private let presenter: (any FilePresentationCoordinating)?
    private var subscription: AnyCancellable?

    public init(queue: any ReviewQueueProtocol, presenter: (any FilePresentationCoordinating)? = nil, reportService: (any QueueReportServiceProtocol)? = nil) {
        self.reportService = reportService
        self.queue = queue; self.presenter = presenter; snapshot = queue.snapshot
        subscription = queue.updates.sink { [weak self] snapshot in self?.receive(snapshot) }
    }
    public var isExecuting: Bool { snapshot.isExecuting }
    public var canExecute: Bool { !isExecuting && !snapshot.items.isEmpty && snapshot.blockers.isEmpty }
    public var logicalBytes: Int64 { snapshot.items.reduce(0) { $0 + $1.file.bytes } }
    public var canPresent: Bool { presenter != nil && !isExecuting }

    public func requestConfirmation() {
        guard canExecute else { return }
        message = nil; confirmationSnapshot = snapshot; showsConfirmation = true
    }
    public func cancelConfirmation() { showsConfirmation = false; confirmationSnapshot = nil }
    public func execute() async {
        guard let approved = confirmationSnapshot, canExecute else { return }
        cancelConfirmation()
        do { try await queue.execute(expectedRevision: approved.revision) }
        catch { message = error.localizedDescription }
    }
    public var canRemeasureFreeSpace: Bool { !isExecuting && snapshot.lastRun?.freeSpace?.beforeBytes != nil }
    public func remeasureFreeSpace() {
        guard canRemeasureFreeSpace else { return }
        queue.remeasureFreeSpace()
    }
    public func remove(_ path: String) { queue.remove(path: path) }
    public func clear() { queue.clear() }
    public func preview(_ path: String) {
        guard canPresent, snapshot.items.contains(where: { $0.id == path }) else { return }
        presenter?.preview(URL(fileURLWithPath: path))
    }
    public func reveal(_ path: String) {
        guard !isExecuting, snapshot.items.contains(where: { $0.id == path }) || snapshot.lastRun?.outcomes.contains(where: { $0.path == path }) == true else { return }
        presenter?.reveal(URL(fileURLWithPath: path))
    }

    private func receive(_ value: ReviewQueueSnapshot) {
        if showsConfirmation, confirmationSnapshot?.revision != value.revision {
            cancelConfirmation(); message = ReviewQueueError.reviewChanged.localizedDescription
        }
        if snapshot.lastRun != value.lastRun { clearReport() }
        snapshot = value
    }
}
