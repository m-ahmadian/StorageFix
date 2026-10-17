import Foundation
import StorageFixCore
import Testing

final class SequencedVolumes: VolumeInformationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var available: [Int64?]
    private let names: [String: String]
    init(available: [Int64?], names: [String: String] = [:]) { self.available = available; self.names = names }
    func volume(at root: URL) -> InventoryVolume? {
        lock.lock(); defer { lock.unlock() }
        let value = available.count > 1 ? available.removeFirst() : available.first ?? nil
        return InventoryVolume(name: names[root.path] ?? "Fixture", capacityBytes: 10_000, availableBytes: value, isReadOnly: false)
    }
}

@MainActor struct FreeSpaceMeasurementTests {
    private func queue(_ volumes: SequencedVolumes, operations: RecordingQueueOperations = RecordingQueueOperations()) -> ReviewQueue {
        ReviewQueue(policy: ReviewFilePolicy(protectedRoots: []), operations: operations, volumes: volumes)
    }
    private func run(_ queue: ReviewQueue, files: [String] = ["a"]) async throws -> ReviewQueueRun? {
        queue.registerInventory(QueueFixtures.scan(files.map { QueueFixtures.file($0) }), origin: .files)
        _ = queue.add(paths: Set(files.map { "/fixture/\($0)" }), origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        return queue.snapshot.lastRun
    }

    @Test func `Given a readable volume, when files move, then before and after free space are observed separately from logical bytes`() async throws {
        let queue = queue(SequencedVolumes(available: [1_000, 1_000, 1_250]))
        let measurement = try #require(try await run(queue)?.freeSpace)
        #expect(measurement.beforeBytes == 1_000 && measurement.afterBytes == 1_250)
        #expect(measurement.changeBytes == 250 && measurement.isMeasured)
    }

    @Test func `Given unchanged free space after Trash, then the change is zero rather than the moved size`() async throws {
        let queue = queue(SequencedVolumes(available: [800]))
        let run = try #require(try await run(queue))
        #expect(run.freeSpace?.changeBytes == 0)
        #expect(run.movedCount == 1)
    }

    @Test func `Given an unreadable volume, then free space is reported unavailable without blocking the move`() async throws {
        let queue = queue(SequencedVolumes(available: [nil]))
        let run = try #require(try await run(queue))
        #expect(run.movedCount == 1)
        #expect(run.freeSpace?.isMeasured == false && run.freeSpace?.unavailableReason != nil)
    }

    @Test func `Given a failed preflight, then nothing moves and no free-space change is recorded`() async throws {
        let queue = queue(SequencedVolumes(available: [500]), operations: RecordingQueueOperations(invalidPath: "/fixture/a"))
        let run = try #require(try await run(queue))
        #expect(run.movedCount == 0 && run.freeSpace == nil)
    }

    @Test func `Given files on two volumes, then free space is not measured as one volume`() async throws {
        let volumes = SequencedVolumes(available: [500], names: ["/fixture": "One", "/other": "Two"])
        let queue = queue(volumes)
        queue.registerInventory(QueueFixtures.scan([QueueFixtures.file("a")]), origin: .files)
        let other = DuplicateFile(path: "/other/b", bytes: 100, modifiedAt: Date(timeIntervalSince1970: 100), fileIdentity: "device:b")
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: URL(fileURLWithPath: "/other"), options: InventoryOptions(),
            files: [other], volume: InventoryVolume(name: "Two", capacityBytes: 1000, availableBytes: 500, isReadOnly: false)), origin: .map)
        _ = queue.add(paths: ["/fixture/a"], origin: .files); _ = queue.add(paths: ["/other/b"], origin: .map)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        let measurement = try #require(queue.snapshot.lastRun?.freeSpace)
        #expect(!measurement.isMeasured && measurement.unavailableReason?.contains("more than one volume") == true)
    }

    @Test func `Remeasuring updates only the observation and keeps the operation and revision`() async throws {
        let queue = queue(SequencedVolumes(available: [1_000, 1_000, 1_000, 1_000, 4_000]))
        let first = try #require(try await run(queue))
        let revision = queue.snapshot.revision
        queue.remeasureFreeSpace()
        let second = try #require(queue.snapshot.lastRun)
        #expect(second.id == first.id && second.outcomes == first.outcomes && queue.snapshot.revision == revision)
        #expect(second.freeSpace?.beforeBytes == 1_000 && second.freeSpace?.afterBytes == 4_000)
    }

    @Test func `Change is unavailable rather than wrapped when values overflow`() {
        let measurement = FreeSpaceMeasurement(beforeBytes: .min, afterBytes: .max)
        #expect(measurement.changeBytes == nil && !measurement.isMeasured)
    }

    @Test func `Reports carry measured observations with the whole-volume caveat`() async throws {
        let run = ReviewQueueRun(date: Date(timeIntervalSince1970: 100),
            outcomes: [ReviewQueueOutcome(path: "/p/a", logicalBytes: 100, status: .moved, message: "Moved")],
            freeSpace: FreeSpaceMeasurement(beforeBytes: 1_000, afterBytes: 900))
        let report = QueueOutcomeReport(run: run, includesPaths: false)
        #expect(report.schemaVersion == 2 && report.freeSpaceChangeBytes == -100)
        #expect(report.spaceRecovery.contains("-100 bytes") && report.spaceRecovery.contains("emptied in Finder"))
        let text = try await QueueReportService().makeReport(run: run, includesPaths: false, format: .text).text
        #expect(text.contains("Measured volume free space"))
    }

    @Test func `Unavailable measurements keep the not-measured wording`() {
        let run = ReviewQueueRun(outcomes: [], freeSpace: .unavailable("The volume did not report its free space."))
        let report = QueueOutcomeReport(run: run, includesPaths: false)
        #expect(report.spaceRecovery.hasPrefix("Not measured.") && report.freeSpaceChangeBytes == nil)
    }
}
