import Combine
import Foundation
import StorageFixCore

@MainActor public final class ScanComparisonViewModel: ObservableObject {
    @Published public private(set) var currentScan: InventoryScan?
    @Published public private(set) var baseline: ScanSnapshot?
    @Published public private(set) var comparison: ScanComparison?
    @Published public private(set) var exportText: String?
    @Published public private(set) var isLoading = false
    @Published public private(set) var message: String?
    private let service: any ScanSnapshotServiceProtocol
    private var subscription: AnyCancellable?
    private var generation = UUID()
    public init(session: any ScanComparisonSessionProtocol, service: any ScanSnapshotServiceProtocol) {
        self.service = service; currentScan = session.currentScan
        subscription = session.updates.sink { [weak self] scan in
            guard let self else { return }
            self.generation = UUID(); self.isLoading = false
            self.currentScan = scan; self.comparison = nil; self.message = nil
        }
    }
    public var canCapture: Bool { currentScan != nil && !isLoading }
    public var canCompare: Bool { canCapture && baseline != nil }
    public func captureBaseline() async {
        guard let scan = currentScan, !isLoading else { return }
        await perform { try await self.service.capture(scan) }
    }
    public func importBaseline(from url: URL) async {
        guard !isLoading else { return }
        await perform { try await self.service.read(from: url) }
    }
    private func perform(_ operation: () async throws -> ScanSnapshot) async {
        let token = UUID(); generation = token; isLoading = true; message = nil
        defer { if generation == token { isLoading = false } }
        do {
            let snapshot = try await operation()
            let text = try await service.document(for: snapshot)
            try Task.checkCancellation()
            guard generation == token else { return }
            baseline = snapshot; exportText = text; comparison = nil
        } catch is CancellationError { }
        catch { if generation == token { message = error.localizedDescription } }
    }
    public func compare() async {
        guard let scan = currentScan, let baseline, !isLoading else { return }
        let token = UUID(); generation = token; isLoading = true; message = nil; comparison = nil
        defer { if generation == token { isLoading = false } }
        do {
            let current = try await service.capture(scan)
            let result = try await service.compare(baseline: baseline, current: current)
            try Task.checkCancellation()
            guard generation == token else { return }
            comparison = result
        } catch is CancellationError { }
        catch { if generation == token { message = error.localizedDescription } }
    }
    public func clearBaseline() {
        generation = UUID(); isLoading = false; baseline = nil; exportText = nil; comparison = nil; message = nil
    }
    public func cancel() { generation = UUID(); isLoading = false }
    public func finishedFileOperation(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            let error = error as NSError
            if error.domain != NSCocoaErrorDomain || error.code != NSUserCancelledError { message = error.localizedDescription }
        }
    }
}
