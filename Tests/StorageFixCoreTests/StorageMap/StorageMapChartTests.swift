import Foundation
import StorageFixCore
import Testing

struct StorageMapChartTests {
    @Test(arguments: Array(0...12))
    func `Given a folder inventory, when charting, then every inventoried byte remains represented`(count: Int) {
        let files = (0..<count).map { DuplicateFile(path: "/fixture/item-\($0)", bytes: Int64($0 + 1)) }
        let items = StorageMap.items(files: files, at: URL(fileURLWithPath: "/fixture"))
        let slices = StorageMap.chartSlices(items: items)
        #expect(slices.reduce(0) { $0 + $1.bytes } == items.reduce(0) { $0 + $1.bytes })
        #expect(slices.count <= StorageMap.primaryChartItemCount + 1)
        #expect(Set(slices.map(\.id)).count == slices.count)
        #expect(slices.contains { $0.id == .remainder } == (count > StorageMap.primaryChartItemCount))
    }

    @Test func `Given eight ranked items, when charting, then the remainder contains the smaller three`() throws {
        let files = (1...8).map { DuplicateFile(path: "/fixture/item-\($0)", bytes: Int64($0) * 100) }
        let items = StorageMap.items(files: files, at: URL(fileURLWithPath: "/fixture"))
        let slices = StorageMap.chartSlices(items: items)
        #expect(slices.prefix(5).map(\.bytes) == [800, 700, 600, 500, 400])
        let remainder = try #require(slices.last)
        #expect(remainder.id == .remainder && remainder.bytes == 600 && remainder.itemCount == 3)
    }

    @Test func `Given a file named Other items, when charting, then its identity differs from the aggregate`() {
        let files = [DuplicateFile(path: "/fixture/Other items", bytes: 100)] +
            (1...7).map { DuplicateFile(path: "/fixture/item-\($0)", bytes: Int64($0)) }
        let slices = StorageMap.chartSlices(items: StorageMap.items(files: files, at: URL(fileURLWithPath: "/fixture")))
        #expect(slices.first?.id == .item("/fixture/Other items"))
        #expect(slices.last?.id == .remainder)
        #expect(Set(slices.map(\.id)).count == slices.count)
    }
}
