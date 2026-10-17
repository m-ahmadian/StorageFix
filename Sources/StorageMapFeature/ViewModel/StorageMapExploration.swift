import Foundation
import StorageFixCore

extension StorageMapViewModel {
    public var selectedItem: StorageMapItem? {
        guard case .item(let path) = selectedID else { return nil }
        return items.first { $0.path == path }
    }
    public var canPreview: Bool { presenter != nil && selectedItem?.isFolder == false }
    public var canReveal: Bool { presenter != nil && selectedItem != nil }
    public var selectionTitle: String {
        if let item = selectedItem { return "\(item.name) · \(sizeDescription(item.bytes)) · \(shareDescription(item.bytes)) of folder" }
        return selectedID == .remainder ? "Other items · choose an item from the list" : "Select a segment or file to inspect it"
    }
    public var selectionPath: String? { selectedItem?.path }
    public var breadcrumbs: [MapBreadcrumb] {
        var result: [MapBreadcrumb] = []
        var folder = current
        while folder.path != root.path && folder.path.hasPrefix(root.path == "/" ? "/" : root.path + "/") {
            result.insert(MapBreadcrumb(path: folder.path, name: folder.lastPathComponent), at: 0)
            folder = folder.deletingLastPathComponent()
        }
        result.insert(MapBreadcrumb(path: root.path, name: root.lastPathComponent.isEmpty ? "/" : root.lastPathComponent), at: 0)
        return result
    }

    public func setQuery(_ value: String) { query = value; updateVisibleItems() }
    public func setSort(_ value: MapSort) { sort = value; updateVisibleItems() }
    public func setMapStyle(_ value: MapStyle) { mapStyle = value; updateSunburst() }
    public func selectItem(_ item: StorageMapItem) { selectSlice(.item(item.path)) }
    public func selectSlice(_ id: StorageMapSlice.ID?) {
        guard !isLoading else { return }
        guard let id else { selectedID = nil; return }
        switch id {
        case .item(let path): guard items.contains(where: { $0.path == path }) else { return }
        case .remainder: guard chartSlices.contains(where: { $0.id == id }) else { return }
        }
        selectedID = id
    }

    public var selectedAngle: Double? {
        var total = 0.0
        for slice in chartSlices {
            if isSliceSelected(slice.id) { return total + Double(slice.bytes) / 2 }
            total += Double(slice.bytes)
        }
        return nil
    }

    public func selectAngle(_ value: Double?) {
        guard let value, value.isFinite, value >= 0, value < Double(totalBytes) else { selectSlice(nil); return }
        var upperBound = 0.0
        for slice in chartSlices {
            upperBound += Double(slice.bytes)
            if value < upperBound { selectSlice(slice.id); return }
        }
    }

    public func isSliceSelected(_ id: StorageMapSlice.ID) -> Bool {
        if id == selectedID { return true }
        guard id == .remainder, let selectedID else { return false }
        return !chartSlices.contains { $0.id == selectedID }
    }

    public func moveSelection(by offset: Int) {
        guard !visibleItems.isEmpty else { return }
        let currentIndex = visibleItems.firstIndex { .item($0.path) == selectedID }
        let index = currentIndex.map { min(max($0 + offset, 0), visibleItems.count - 1) } ?? 0
        selectItem(visibleItems[index])
    }
    public func exploreSelection() { if let selectedItem { enter(selectedItem) } }
    public func previewSelection() { if canPreview, let item = selectedItem { presenter?.preview(URL(fileURLWithPath: item.path)) } }
    public func revealSelection() { if let item = selectedItem { presenter?.reveal(URL(fileURLWithPath: item.path)) } }
    public func reveal(_ item: StorageMapItem) {
        guard items.contains(item) else { return }
        presenter?.reveal(URL(fileURLWithPath: item.path))
    }
    public func navigate(to breadcrumb: MapBreadcrumb) {
        guard !isLoading, breadcrumbs.contains(breadcrumb) else { return }
        current = URL(fileURLWithPath: breadcrumb.path)
        updateProjection()
    }

    func updateVisibleItems() {
        let filtered = items.filter { query.isEmpty || $0.path.localizedCaseInsensitiveContains(query) }
        switch sort {
        case .largest: visibleItems = filtered
        case .smallest: visibleItems = filtered.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes < $1.bytes }
        case .name: visibleItems = filtered.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
    }
}
