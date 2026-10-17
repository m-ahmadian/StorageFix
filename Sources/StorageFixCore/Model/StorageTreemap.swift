/// Normalized, deterministic binary treemap layout. Area represents logical bytes.
public struct StorageTreemapCell: Identifiable, Equatable, Sendable {
    public let slice: StorageMapSlice
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public var id: StorageMapSlice.ID { slice.id }
}

public enum StorageTreemap {
    public static func cells(slices: [StorageMapSlice]) -> [StorageTreemapCell] {
        partition(slices.filter { $0.bytes > 0 }, x: 0, y: 0, width: 1, height: 1)
    }

    private static func partition(_ slices: [StorageMapSlice], x: Double, y: Double,
                                  width: Double, height: Double) -> [StorageTreemapCell] {
        guard let first = slices.first else { return [] }
        if slices.count == 1 {
            return [StorageTreemapCell(slice: first, x: x, y: y, width: width, height: height)]
        }
        let total = slices.reduce(0.0) { $0 + Double($1.bytes) }
        var split = 1
        var accumulated = Double(first.bytes)
        while split < slices.count - 1,
              abs(accumulated + Double(slices[split].bytes) - total / 2) < abs(accumulated - total / 2) {
            accumulated += Double(slices[split].bytes); split += 1
        }
        let ratio = accumulated / total
        let left = Array(slices.prefix(split)), right = Array(slices.dropFirst(split))
        if width >= height {
            return partition(left, x: x, y: y, width: width * ratio, height: height)
                + partition(right, x: x + width * ratio, y: y, width: width * (1 - ratio), height: height)
        }
        return partition(left, x: x, y: y, width: width, height: height * ratio)
            + partition(right, x: x, y: y + height * ratio, width: width, height: height * (1 - ratio))
    }
}
