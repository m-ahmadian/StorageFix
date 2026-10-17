import Foundation
import StorageFixCore

@MainActor
public final class CleanupViewModel: ObservableObject {
    @Published public private(set) var hasScanned = false
    @Published public private(set) var operationDescription = "Scanning caches…"
    @Published public private(set) var categories: [CleanupCategory] = []
    @Published public private(set) var selectedCategoryIDs: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isCleaning = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public private(set) var freeBytesBefore: Int64?
    @Published public private(set) var freeBytesAfter: Int64?
    @Published public private(set) var freeBytesReclaimed: Int64 = 0
    @Published public private(set) var hasCleanupSummary = false
    @Published public var showsConfirmation = false
    /// True until the person grants the folder this edition's cleanup requires (the sandboxed build needs Home).
    @Published public private(set) var needsAccess: Bool

    private let service: any CleanupServiceProtocol
    private let byteFormatter: ByteCountFormatter

    public init(service: any CleanupServiceProtocol) {
        self.service = service
        needsAccess = service.requiredFolder != nil
        byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
    }

    public var selectedBytes: Int64 {
        categories
            .filter { selectedCategoryIDs.contains($0.id) }
            .reduce(0) { $0 + $1.bytesAfter }
    }

    public var cleanableBytes: Int64 {
        categories.reduce(0) { $0 + $1.bytesAfter }
    }

    public var selectedSizeDescription: String {
        sizeDescription(forByteCount: selectedBytes)
    }

    public var cleanableSizeDescription: String {
        sizeDescription(forByteCount: cleanableBytes)
    }

    public var remainingCleanableSizeDescription: String {
        cleanableSizeDescription
    }

    public var hasRemainingCleanableSpace: Bool {
        hasCleanupSummary && cleanableBytes > 0
    }

    public var freeSpaceBeforeDescription: String {
        freeBytesBefore.map { sizeDescription(forByteCount: $0) } ?? "—"
    }

    public var freeSpaceAfterDescription: String {
        freeBytesAfter.map { sizeDescription(forByteCount: $0) } ?? "—"
    }

    public var reclaimedSpaceDescription: String {
        sizeDescription(forByteCount: freeBytesReclaimed)
    }

    public var hasSelectableCategories: Bool {
        selectableCategoryIDs.isEmpty == false
    }

    public var areAllCategoriesSelected: Bool {
        hasSelectableCategories && selectedCategoryIDs.isSuperset(of: selectableCategoryIDs)
    }

    public var selectAllButtonTitle: String {
        areAllCategoriesSelected ? "Deselect All" : "Select All"
    }

    public func sizeDescription(for category: CleanupCategory) -> String {
        sizeDescription(forByteCount: category.bytesAfter)
    }

    public func categories(in group: CleanupGroup) -> [CleanupCategory] {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        return group.categoryIDs.compactMap { categoriesByID[$0] }
    }

    public func groupBytes(for group: CleanupGroup) -> Int64 {
        categories(in: group).reduce(0) { $0 + $1.bytesAfter }
    }

    public func groupSizeDescription(for group: CleanupGroup) -> String {
        sizeDescription(forByteCount: groupBytes(for: group))
    }

    public func groupSelectionState(for group: CleanupGroup) -> CleanupGroupSelectionState {
        let groupIDs = selectableCategoryIDs(in: group)
        let selectedCount = groupIDs.intersection(selectedCategoryIDs).count
        guard selectedCount > 0 else { return .none }
        return selectedCount == groupIDs.count ? .all : .some
    }

    public func isCategorySelected(_ id: String) -> Bool {
        selectedCategoryIDs.contains(id)
    }

    public func setCategory(_ id: String, isSelected: Bool) {
        guard !isLoading else { return }
        guard selectableCategoryIDs.contains(id) else {
            selectedCategoryIDs.remove(id)
            return
        }
        if isSelected {
            selectedCategoryIDs.insert(id)
        } else {
            selectedCategoryIDs.remove(id)
        }
    }

    public func toggleGroup(_ group: CleanupGroup) {
        guard !isLoading else { return }
        let groupIDs = selectableCategoryIDs(in: group)
        if groupSelectionState(for: group) == .all {
            selectedCategoryIDs.subtract(groupIDs)
        } else {
            selectedCategoryIDs.formUnion(groupIDs)
        }
    }

    public func toggleSelectAll() {
        guard !isLoading else { return }
        if areAllCategoriesSelected {
            selectedCategoryIDs.removeAll()
        } else {
            selectedCategoryIDs = selectableCategoryIDs
        }
    }

    /// The folder to preselect in the access panel, when one is required.
    public var requiredFolder: URL? { service.requiredFolder }

    /// Grants the chosen folder and scans. A wrong folder leaves access unchanged and explains why.
    public func grantAccess(to folder: URL) async {
        guard !isLoading else { return }
        do {
            try await service.grantAccess(to: folder)
            needsAccess = !(await service.hasAccess)
            errorMessage = nil
            if !needsAccess { await scan() }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Quietly accepts a folder chosen elsewhere (e.g. Quick Review) when it is the required one.
    public func offerFolder(_ folder: URL) async {
        guard needsAccess, let required = requiredFolder,
              folder.resolvingSymlinksInPath().standardizedFileURL.path == required.resolvingSymlinksInPath().standardizedFileURL.path else { return }
        try? await service.grantAccess(to: folder)
        needsAccess = !(await service.hasAccess)
    }

    public func scan() async {
        guard !isLoading, !needsAccess else { return }
        operationDescription = "Scanning caches…"
        await perform {
            let report = try await service.scan()
            categories = report.categories
            updateStorageSummary(with: report, isCleanup: false)
            if hasScanned {
                selectedCategoryIDs.formIntersection(selectableCategoryIDs)
            } else {
                selectedCategoryIDs = Set(report.categories.filter { $0.safeDefault && $0.bytesAfter > 0 }.map(\.id))
            }
            hasScanned = true
            resultMessage = nil
        }
    }

    public func requestCleanup() {
        guard !isLoading else { return }
        guard !selectedCategoryIDs.isEmpty else {
            errorMessage = "Select at least one cleanup category."
            return
        }
        showsConfirmation = true
    }

    public func confirmCleanup() async {
        guard !isLoading, !selectedCategoryIDs.isEmpty else { return }
        showsConfirmation = false
        operationDescription = "Cleaning selected caches…"
        isCleaning = true
        defer { isCleaning = false }
        let selectedIDs = selectedCategoryIDs
        await perform {
            let report = try await service.clean(categoryIDs: selectedIDs)
            categories = report.categories
            updateStorageSummary(with: report, isCleanup: true)
            selectedCategoryIDs.removeAll()
            let skipped = report.categories.filter { $0.status == .blocked || $0.status == .failed }
            resultMessage = "Cleanup reclaimed \(reclaimedSpaceDescription)."
            if !skipped.isEmpty {
                errorMessage = skipped.map { "\($0.name): \($0.message)" }.joined(separator: "\n")
                resultMessage = "Cleanup finished with \(skipped.count) skipped or failed categories. Reclaimed \(reclaimedSpaceDescription)."
            }
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        resultMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch is CancellationError {
            resultMessage = "Operation cancelled. Rescan before making further changes."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var selectableCategoryIDs: Set<String> {
        Set(categories.filter { $0.bytesAfter > 0 }.map(\.id))
    }

    private func selectableCategoryIDs(in group: CleanupGroup) -> Set<String> {
        Set(categories(in: group).filter { $0.bytesAfter > 0 }.map(\.id))
    }

    private func updateStorageSummary(with report: CleanupReport, isCleanup: Bool) {
        freeBytesBefore = report.freeBytesBefore
        freeBytesAfter = report.freeBytesAfter
        freeBytesReclaimed = report.freeBytesReclaimed
        hasCleanupSummary = isCleanup
    }

    private func sizeDescription(forByteCount bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }
}
