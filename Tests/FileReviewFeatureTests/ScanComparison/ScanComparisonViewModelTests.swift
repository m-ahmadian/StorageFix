import Foundation
import ScanComparisonFeature
import StorageMapFeature
import StorageFixCore
import Testing

@MainActor struct ScanComparisonViewModelTests {
    private func scan(_ bytes: Int64 = 10) -> InventoryScan {
        InventoryScan(sessionID: UUID(), root: URL(fileURLWithPath: "/fixture"), options: InventoryOptions(),
                      files: [DuplicateFile(path: "/fixture/a", bytes: bytes)])
    }
    @Test func `Captured baseline survives rescan and current comparison updates`() async throws {
        let session = ScanComparisonSession(); session.receive(scan())
        let vm = ScanComparisonViewModel(session: session, service: ScanSnapshotService())
        await vm.captureBaseline()
        #expect(vm.baseline?.logicalBytes == 10 && vm.exportText != nil)
        session.receive(scan(20)); await vm.compare()
        #expect(vm.comparison?.observedByteChange == 10 && !vm.isLoading)
        session.receive(nil)
        #expect(vm.comparison == nil && vm.baseline != nil && !vm.canCompare)
        vm.clearBaseline()
        #expect(vm.baseline == nil && vm.exportText == nil)
    }
    @Test func `Snapshot failures clear loading and retain an actionable message`() async {
        let session = ScanComparisonSession(); session.receive(scan())
        let vm = ScanComparisonViewModel(session: session, service: FailedSnapshotService())
        await vm.captureBaseline()
        #expect(!vm.isLoading && vm.message != nil && vm.baseline == nil)
        await vm.importBaseline(from: URL(fileURLWithPath: "/missing"))
        #expect(!vm.isLoading && vm.message != nil && vm.exportText == nil)
    }
    @Test(arguments: [false, true])
    func `Loading state is visible and a newer scan discards late capture results`(invalidate: Bool) async throws {
        let session = ScanComparisonSession(); session.receive(scan())
        let service = PausedSnapshotService()
        let controlled = ScanComparisonViewModel(session: session, service: service)
        let task = Task { await controlled.captureBaseline() }
        await service.waitUntilStarted()
        #expect(controlled.isLoading && !controlled.canCapture)
        if invalidate { session.receive(scan(30)) }
        await service.finish(); await task.value
        #expect(!controlled.isLoading)
        #expect(invalidate ? controlled.baseline == nil : controlled.baseline != nil)
    }
    @Test func `Map scans supply comparison metadata without granting snapshot removal access`() async throws {
        let session = ScanComparisonSession()
        let map = StorageMapFeature.StorageMapViewModel(root: URL(fileURLWithPath: "/fixture"), service: MapInventoryFixture(), comparisonSession: session)
        await map.scan()
        #expect(session.currentScan?.sessionID == map.inventoryResult?.sessionID)
        map.chooseFolder(URL(fileURLWithPath: "/different"))
        #expect(session.currentScan == nil)
    }
}

private struct FailedSnapshotService: ScanSnapshotServiceProtocol {
    func capture(_ scan: InventoryScan) async throws -> ScanSnapshot { throw ScanSnapshotError.invalidDocument }
    func read(from url: URL) async throws -> ScanSnapshot { throw ScanSnapshotError.invalidDocument }
    func document(for snapshot: ScanSnapshot) async throws -> String { throw ScanSnapshotError.invalidDocument }
    func compare(baseline: ScanSnapshot, current: ScanSnapshot) async throws -> ScanComparison { throw ScanSnapshotError.invalidDocument }
}
private actor PausedSnapshotService: ScanSnapshotServiceProtocol {
    private var started = false
    private var observer: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func capture(_ scan: InventoryScan) async throws -> ScanSnapshot {
        started = true; observer?.resume(); observer = nil
        await withCheckedContinuation { waiter = $0 }
        return ScanSnapshot(scan: scan)
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() { waiter?.resume(); waiter = nil }
    func read(from url: URL) async throws -> ScanSnapshot { throw ScanSnapshotError.invalidDocument }
    func document(for snapshot: ScanSnapshot) async throws -> String { "snapshot fixture" }
    func compare(baseline: ScanSnapshot, current: ScanSnapshot) async throws -> ScanComparison { throw ScanSnapshotError.invalidDocument }
}
