import Combine
import Foundation
import StorageFixCore

@MainActor
public final class DuplicateViewModel: ObservableObject {
    @Published public private(set) var groups: [DuplicateGroup] = []
    @Published public private(set) var selectedPaths: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRemoving = false
    @Published public private(set) var hasScanned = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public private(set) var scopeDescription = "Desktop, Documents & Downloads"
    @Published public var showsConfirmation = false
    @Published public private(set) var needsFolder: Bool
    @Published public private(set) var queueAddResult: ReviewQueueAddResult?
    let queue: (any ReviewQueueProtocol)?
    private var scope: URL?
    private var queueSubscription: AnyCancellable?
    let presenter: (any FilePresentationCoordinating)?
    private let service: any DuplicateServiceProtocol
    public init(service: any DuplicateServiceProtocol, scopeDescription: String = "Desktop, Documents & Downloads", requiresFolderSelection: Bool = false, queue: (any ReviewQueueProtocol)? = nil, presenter: (any FilePresentationCoordinating)? = nil) {
        self.service = service; self.queue = queue; self.presenter = presenter
        scope = scopeDescription.hasPrefix("/") ? URL(fileURLWithPath: scopeDescription) : nil
        self.scopeDescription = requiresFolderSelection ? "Choose a folder to review" : scopeDescription
        needsFolder = requiresFolderSelection
        queueSubscription = queue?.finishedRuns.sink { [weak self] _ in self?.invalidateAfterQueue() }
    }

    public var usesReviewQueue: Bool { queue != nil }
    public var isQueueBusy: Bool { queue?.snapshot.isExecuting == true }
    public func reviewSelected() {
        if usesReviewQueue { addSelectedToQueue() } else { showsConfirmation = true }
    }
    private func addSelectedToQueue() {
        guard !isLoading, !isQueueBusy, let queue else { return }
        let result = queue.add(paths: selectedPaths, origin: .duplicates)
        queueAddResult = result; resultMessage = result.message + " Open Review Queue to continue."
        if result.rejections.isEmpty { selectedPaths = [] }
    }
    private func registerQueueInventory() {
        if let scope { queue?.registerDuplicates(groups, root: scope) }
    }
    private func invalidateAfterQueue() {
        groups = []; selectedPaths = []; hasScanned = false; queueAddResult = nil
        resultMessage = "Queue operation finished. Scan again to refresh duplicate review."
    }

    public var selectedBytes: Int64 {
        groups.flatMap(\.duplicates).filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.bytes }
    }
    public var selectedFiles: [DuplicateFile] { groups.flatMap { [$0.original] + $0.duplicates }.filter { selectedPaths.contains($0.path) } }
    public var duplicateCount: Int { groups.reduce(0) { $0 + $1.duplicates.count } }

    public func chooseFolder(_ folder: URL) {
        guard !isLoading, !isQueueBusy else { return }
        needsFolder = false
        scope = folder
        scopeDescription = folder.path
        groups = []; selectedPaths = []; hasScanned = false
        errorMessage = nil; resultMessage = nil
    }

    public func scan() async {
        guard !isLoading, !isQueueBusy else { return }
        guard !needsFolder else { errorMessage = "Choose a folder to grant access before scanning."; return }
        isLoading = true; errorMessage = nil; resultMessage = nil
        selectedPaths = []; groups = []; hasScanned = false
        defer { isLoading = false }
        do {
            groups = try await service.scan(in: scope)
            try Task.checkCancellation()
            hasScanned = true
            registerQueueInventory()
            // Copies start unselected so the user explicitly reviews each removal.
        } catch is CancellationError {
            resultMessage = "Scan cancelled. No files were changed."
        } catch { errorMessage = error.localizedDescription }
    }

    public func reveal(_ path: String) { service.reveal(path: path) }
    public func setSelected(path: String, isSelected: Bool) {
        guard !isLoading, !isQueueBusy, groups.flatMap(\.duplicates).contains(where: { $0.path == path }) else { return }
        if isSelected { selectedPaths.insert(path) } else { selectedPaths.remove(path) }
    }
    public func toggleSelectAll() {
        guard !isLoading, !isQueueBusy else { return }
        let copies = Set(groups.flatMap(\.duplicates).map(\.path))
        selectedPaths = selectedPaths == copies ? [] : copies
    }
    public func keep(path: String, in groupID: String) {
        guard !isLoading, !isQueueBusy, let index = groups.firstIndex(where: { $0.id == groupID }),
              let replacement = groups[index].duplicates.first(where: { $0.path == path }) else { return }
        let old = groups[index].original
        groups[index] = DuplicateGroup(id: groupID, original: replacement, duplicates: [old] + groups[index].duplicates.filter { $0.path != path })
        selectedPaths.remove(path)
        // Switching the kept copy must not silently select the previous original.
        selectedPaths.remove(old.path)
        registerQueueInventory()
    }
    public func remove() async {
        if usesReviewQueue { showsConfirmation = false; addSelectedToQueue(); return }
        guard !isLoading, !selectedPaths.isEmpty else { return }
        showsConfirmation = false
        let paths = selectedPaths
        isLoading = true; isRemoving = true; errorMessage = nil; resultMessage = nil
        defer { isLoading = false; isRemoving = false }
        do {
            try await service.remove(paths: paths)
            groups = groups.compactMap { group in
                let copies = group.duplicates.filter { !paths.contains($0.path) }
                return copies.isEmpty ? nil : DuplicateGroup(id: group.id, original: group.original, duplicates: copies)
            }
            selectedPaths = []
            resultMessage = "Moved \(paths.count) copies to Trash. Restore them in Finder if needed. Space is freed when you empty Trash. Scan again before another removal."
            // Service requires a fresh scan after removal.
            groups = []; hasScanned = false
        } catch {
            groups = []; selectedPaths = []; hasScanned = false
            errorMessage = "\(error.localizedDescription) Some copies may already be in Trash. Scan again to refresh the results."
        }
    }
}
