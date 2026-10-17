import Foundation
@testable import StorageFixCore
import Testing

struct ScanFolderChangesTests {
    private func comparison(_ items: [ScanComparison.Item]) -> ScanComparison {
        ScanComparison(baselineID: UUID(), currentID: UUID(), beforeBytes: 0, afterBytes: 0, unchangedCount: 0, warnings: [], items: items)
    }

    @Test func `Folder changes net growth and shrinkage per top-level folder, largest first`() {
        let result = comparison([
            .init(path: "Videos/a.mov", change: .newlyObserved, beforeBytes: nil, afterBytes: 900),
            .init(path: "Videos/old.mov", change: .noLongerObserved, beforeBytes: 100, afterBytes: nil),
            .init(path: "Downloads/x.zip", change: .noLongerObserved, beforeBytes: 300, afterBytes: nil),
            .init(path: "notes.txt", change: .metadataChanged, beforeBytes: 10, afterBytes: 15)
        ]).folderChanges()
        #expect(result.map(\.folder) == ["Videos", "Downloads", nil])
        #expect(result.map(\.byteChange) == [800, -300, 5])
        #expect(result.first?.changedPaths == 2)
    }

    @Test func `Changes that cancel out are kept and the limit is applied`() {
        let items = (0..<8).map { ScanComparison.Item(path: "F\($0)/a", change: .metadataChanged, beforeBytes: 10, afterBytes: 10 + Int64($0)) }
            + [.init(path: "Same/a", change: .metadataChanged, beforeBytes: 50, afterBytes: 50)]
        let result = comparison(items).folderChanges(limit: 3)
        #expect(result.count == 3 && result.first?.folder == "F7")
        #expect(comparison(items).folderChanges(limit: 20).contains { $0.folder == "Same" && $0.byteChange == 0 })
    }

    @Test func `An empty comparison has no folder changes`() {
        #expect(comparison([]).folderChanges().isEmpty)
    }
}
