import Foundation
import StorageFixCore

extension StorageMapViewModel {
    func updateSunburst() {
        sunburstSegments = mapStyle == .sunburst ? StorageSunburst.segments(files: files, root: current, items: items, index: projectionIndex) : []
    }
    public func activateSunburst(_ segment: StorageSunburstSegment) {
        guard !isLoading, !isQueueBusy, sunburstSegments.contains(segment) else { return }
        if let parent = segment.parentPath, let folder = items.first(where: { $0.path == parent && $0.isFolder }) { enter(folder) }
        selectSlice(segment.slice.id)
    }
    func sunburstDetail(_ segment: StorageSunburstSegment) -> String {
        "\(segment.slice.name) · \(sizeDescription(segment.slice.bytes)) · \(shareDescription(segment.slice.bytes)) of this folder"
    }
}
