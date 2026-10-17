import Foundation
import StorageFixCore

extension StorageMapViewModel {
    func colorIndex(for item: StorageMapItem) -> Int { colorIndices[item.id] ?? StorageMap.primaryChartItemCount }
    var listEmptyTitle: String {
        if !query.isEmpty && !items.isEmpty { return "No matches in this folder" }
        return hasScanned ? "No inventoried files here" : "Your space, at a glance"
    }
    var listEmptyDescription: String {
        if !query.isEmpty && !items.isEmpty { return "Clear the search or return to a parent folder." }
        return hasScanned ? "Choose another folder to explore." : "Choose a folder to see its inventoried file sizes. APFS sharing may change actual disk usage."
    }

    var chartAccessibilityValue: String {
        chartSlices.map { "\(sliceTitle($0)), \(sizeDescription($0.bytes)), \(shareDescription($0.bytes))" }
            .joined(separator: "; ")
    }

    var chartExplanation: String {
        chartSlices.contains { $0.id == .remainder }
            ? "Largest \(StorageMap.primaryChartItemCount) items plus the remaining items. Every inventoried byte is represented."
            : "Every inventoried byte is represented."
    }

    func sliceTitle(_ slice: StorageMapSlice) -> String {
        slice.id == .remainder ? "\(slice.name) (\(slice.itemCount))" : slice.name
    }

    func sizeDescription(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func shareDescription(_ bytes: Int64) -> String {
        let share = totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0
        return share.formatted(.percent.precision(.fractionLength(1)))
    }
}
