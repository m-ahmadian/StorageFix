import StorageFixCore
import Testing

struct StorageTreemapTests {
    private let tolerance = 0.0000001

    @Test(arguments: 0...12)
    func `Treemap preserves logical proportions within nonoverlapping unit bounds`(count: Int) {
        let slices = (0..<count).map { StorageMapSlice(id: .item("/file-\($0)"), name: "File \($0)", bytes: Int64($0 + 1), itemCount: 1) }
        let cells = StorageTreemap.cells(slices: slices)
        #expect(cells.count == count)
        let total = Double(slices.reduce(0) { $0 + $1.bytes })
        for cell in cells {
            #expect(cell.x >= 0 && cell.y >= 0 && cell.x + cell.width <= 1 + tolerance && cell.y + cell.height <= 1 + tolerance)
            #expect(abs(cell.width * cell.height - Double(cell.slice.bytes) / total) < tolerance)
        }
        for (index, left) in cells.enumerated() {
            for right in cells.dropFirst(index + 1) {
                let width = max(0, min(left.x + left.width, right.x + right.width) - max(left.x, right.x))
                let height = max(0, min(left.y + left.height, right.y + right.height) - max(left.y, right.y))
                #expect(width * height < tolerance)
            }
        }
        #expect(StorageTreemap.cells(slices: slices) == cells)
    }

    @Test func `Zero-size files have no area and remain available in the file list`() {
        let slices = [StorageMapSlice(id: .item("/empty"), name: "Empty", bytes: 0, itemCount: 1),
                      StorageMapSlice(id: .item("/file"), name: "File", bytes: 100, itemCount: 1)]
        let cells = StorageTreemap.cells(slices: slices)
        #expect(cells.count == 1 && cells.first?.width == 1 && cells.first?.height == 1)
    }
}
