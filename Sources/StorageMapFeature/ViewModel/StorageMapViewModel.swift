import Combine
import Foundation
import StorageFixCore

@MainActor
public final class StorageMapViewModel: ObservableObject {
    @Published public private(set) var root: URL
    @Published public internal(set) var current: URL
    @Published public private(set) var files: [DuplicateFile] = []
    @Published public private(set) var items: [StorageMapItem] = []
    @Published public private(set) var chartSlices: [StorageMapSlice] = []
    @Published public private(set) var totalBytes: Int64 = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasScanned = false
    @Published public private(set) var errorMessage: String?
    @Published public internal(set) var resultMessage: String?
    @Published public private(set) var needsFolder: Bool
    @Published public private(set) var inventoryResult: InventoryScan?
    @Published public private(set) var progress: InventoryProgress?
    @Published public private(set) var options = InventoryOptions()
    private var activeSession: UUID?
    @Published public internal(set) var selectedID: StorageMapSlice.ID?
    @Published public internal(set) var visibleItems: [StorageMapItem] = []
    @Published public internal(set) var query = ""
    @Published public internal(set) var sort: MapSort = .largest
    @Published public internal(set) var mapStyle: MapStyle = .treemap
    @Published public internal(set) var sunburstSegments: [StorageSunburstSegment] = []
    private var folderProjections: [String: [StorageMapItem]] = [:]
    private var projectionOrder: [String] = []
    private static let cachedFolderLimit = 16
    var colorIndices: [String: Int] = [:]
    let presenter: (any FilePresentationCoordinating)?
    @Published public internal(set) var queueAddResult: ReviewQueueAddResult?
    let queue: (any ReviewQueueProtocol)?
    private var queueSubscription: AnyCancellable?
    private let comparisonSession: (any ScanComparisonSessionProtocol)?
    private let service: any FileInventoryServiceProtocol

    public init(root: URL, service: any FileInventoryServiceProtocol, requiresFolderSelection: Bool = false, presenter: (any FilePresentationCoordinating)? = nil, queue: (any ReviewQueueProtocol)? = nil, comparisonSession: (any ScanComparisonSessionProtocol)? = nil) {
        self.comparisonSession = comparisonSession
        self.queue = queue
        self.presenter = presenter
        self.root = root
        current = root
        self.service = service
        needsFolder = requiresFolderSelection
        queueSubscription = queue?.finishedRuns.sink { [weak self] _ in self?.invalidateAfterQueue() }
    }

    public var coverageSummary: InventorySummary? { inventoryResult.map(InventorySummary.init) }
    public func setHiddenFiles(_ included: Bool) { if !isLoading { options.includesHiddenFiles = included } }
    public func setPackageContents(_ included: Bool) { if !isLoading { options.includesPackageContents = included } }

    public func acceptInventory(_ result: InventoryScan) {
        guard !isLoading, !isQueueBusy else { return }
        acceptInventory(result.files, root: result.root)
        inventoryResult = result
        comparisonSession?.receive(result)
        queue?.registerInventory(result, origin: .map)
    }

    public var canGoBack: Bool { current.standardizedFileURL.path != root.standardizedFileURL.path }

    public func chooseFolder(_ folder: URL) {
        guard !isLoading, !isQueueBusy else { return }
        needsFolder = false
        root = folder.resolvingSymlinksInPath()
        resetInventory()
    }

    public func acceptInventory(_ files: [DuplicateFile], root: URL) {
        guard !isLoading, !isQueueBusy else { return }
        needsFolder = false
        self.root = root
        current = root
        self.files = files
        clearProjectionCache()
        inventoryResult = nil
        comparisonSession?.receive(nil)
        hasScanned = true
        errorMessage = nil
        resultMessage = nil
        updateProjection()
    }

    public func enter(_ item: StorageMapItem) {
        guard !isLoading, item.isFolder, items.contains(item) else { return }
        current = URL(fileURLWithPath: item.path)
        updateProjection()
    }

    public func back() {
        guard !isLoading, canGoBack else { return }
        current = current.deletingLastPathComponent()
        updateProjection()
    }

    public func returnToRoot() {
        guard !isLoading, !isQueueBusy else { return }
        current = root
        updateProjection()
    }

    public func scan() async {
        guard !isLoading, !isQueueBusy else { return }
        guard !needsFolder else {
            errorMessage = "Choose a folder to grant access before scanning."
            return
        }
        resetInventory()
        isLoading = true
        let sessionID = UUID()
        activeSession = sessionID
        defer { isLoading = false; activeSession = nil }
        do {
            let inventory = try await service.inventory(in: root, options: options, sessionID: sessionID) { [weak self] update in
                Task { @MainActor [weak self] in self?.receiveProgress(update) }
            }
            guard activeSession == sessionID, inventory.sessionID == sessionID else { return }
            if Task.isCancelled && !inventory.wasCancelled { throw CancellationError() }
            queue?.registerInventory(inventory, origin: .map)
            inventoryResult = inventory
            comparisonSession?.receive(inventory)
            files = inventory.files
            clearProjectionCache()
            hasScanned = true
            if inventory.wasCancelled { resultMessage = "Scan cancelled. Partial results remain available. No files were changed." }
            updateProjection()
        } catch is CancellationError {
            resultMessage = "Scan cancelled. No files were changed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func receiveProgress(_ update: InventoryProgress) {
        guard isLoading, activeSession == update.sessionID,
              update.visitedCount >= (progress?.visitedCount ?? 0) else { return }
        progress = update
    }

    func resetInventory() {
        clearProjectionCache()
        query = ""
        queueAddResult = nil
        inventoryResult = nil
        comparisonSession?.receive(nil)
        progress = nil
        files = []
        current = root
        hasScanned = false
        errorMessage = nil
        resultMessage = nil
        updateProjection()
    }

    func updateProjection() {
        items = projectedItems(at: current)
        totalBytes = items.reduce(0) { $0 + $1.bytes }
        chartSlices = StorageMap.chartSlices(items: items)
        colorIndices = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) })
        selectedID = nil
        updateVisibleItems()
        updateSunburst()
    }
    private func clearProjectionCache() {
        folderProjections = [:]; projectionOrder = []
    }
    private func projectedItems(at folder: URL) -> [StorageMapItem] {
        let key = folder.path
        if let cached = folderProjections[key] {
            projectionOrder.removeAll { $0 == key }; projectionOrder.append(key)
            return cached
        }
        let result = StorageMap.items(files: files, at: folder)
        if projectionOrder.count >= Self.cachedFolderLimit, let oldest = projectionOrder.first {
            folderProjections.removeValue(forKey: oldest); projectionOrder.removeFirst()
        }
        folderProjections[key] = result; projectionOrder.append(key)
        return result
    }

}
