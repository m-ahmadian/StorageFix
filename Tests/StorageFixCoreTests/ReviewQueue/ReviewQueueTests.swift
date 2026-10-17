import Foundation
import StorageFixCore
import Testing

@MainActor struct ReviewQueueTests {
    @Test func `Cross-feature additions deduplicate exact paths without inflating logical size`() {
        let queue = QueueFixtures.queue()
        let scan = QueueFixtures.scan([QueueFixtures.file("a"), QueueFixtures.file("b")])
        queue.registerInventory(scan, origin: .files); queue.registerInventory(scan, origin: .map)
        #expect(queue.add(paths: ["/fixture/a"], origin: .files).addedCount == 1)
        #expect(queue.add(paths: ["/fixture/a"], origin: .map).existingCount == 1)
        #expect(queue.snapshot.items.count == 1 && queue.snapshot.items.first?.origins == [.files, .map])
        queue.remove(path: "/fixture/a")
        #expect(queue.snapshot.items.isEmpty)
    }

    @Test func `Inspection, cancelled and read-only scans cannot authorize queue entries`() {
        let queue = QueueFixtures.queue()
        var options = InventoryOptions(); options.includesHiddenFiles = true
        for scan in [QueueFixtures.scan([QueueFixtures.file("a")], options: options),
                     QueueFixtures.scan([QueueFixtures.file("a")], cancelled: true),
                     QueueFixtures.scan([QueueFixtures.file("a")], readOnly: true)] {
            queue.registerInventory(scan, origin: .map)
            #expect(queue.add(paths: ["/fixture/a"], origin: .map).rejections.count == 1)
        }
        #expect(queue.snapshot.items.isEmpty)
    }

    @Test func `Protected paths, hidden/package contents, shared links and missing versions are rejected`() {
        let queue = QueueFixtures.queue()
        let files = [QueueFixtures.file("protected/file"), QueueFixtures.file("PROTECTED/file"), QueueFixtures.file("Library/file"), QueueFixtures.file("library/file"), QueueFixtures.file(".secret"), QueueFixtures.file("Bundle.app/file"),
                     DuplicateFile(path: "/fixture/no-version", bytes: 100),
                     DuplicateFile(path: "/fixture/shared", bytes: 100, modifiedAt: Date(), fileIdentity: "id", isSharedLink: true)]
        queue.registerInventory(QueueFixtures.scan(files), origin: .files)
        #expect(queue.add(paths: Set(files.map(\.path)), origin: .files).rejections.count == files.count)
        #expect(queue.snapshot.items.isEmpty)
    }

    @Test(arguments: [false, true])
    func `Ancestor and descendant selections never expand or replace each other`(reverse: Bool) {
        let queue = QueueFixtures.queue()
        let parent = QueueFixtures.file("folder"), child = QueueFixtures.file("folder/file")
        queue.registerInventory(QueueFixtures.scan([parent, child]), origin: .files)
        let first = reverse ? child : parent, second = reverse ? parent : child
        #expect(queue.add(paths: [first.path], origin: .files).addedCount == 1)
        #expect(queue.add(paths: [second.path], origin: .files).rejections.count == 1)
        #expect(queue.snapshot.items.map(\.id) == [first.path])
    }

    @Test func `A kept duplicate cannot enter through any source and late duplicate discovery blocks an existing kept path`() async throws {
        let ops = RecordingQueueOperations()
        let queue = QueueFixtures.queue(operations: ops)
        let kept = QueueFixtures.file("a"), copy = QueueFixtures.file("b")
        queue.registerInventory(QueueFixtures.scan([kept, copy]), origin: .files)
        _ = queue.add(paths: [kept.path], origin: .files)
        queue.registerDuplicates([DuplicateGroup(id: "digest", original: kept, duplicates: [copy])], root: QueueFixtures.root)
        #expect(queue.snapshot.blockers[kept.path] != nil)
        queue.remove(path: kept.path)
        #expect(queue.add(paths: [kept.path], origin: .files).rejections.count == 1)
        #expect(queue.add(paths: [copy.path], origin: .files).addedCount == 1)
        queue.registerDuplicates([DuplicateGroup(id: "digest", original: copy, duplicates: [kept])], root: QueueFixtures.root)
        #expect(queue.snapshot.blockers[copy.path] != nil)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.movedCount == 0)
        #expect(await ops.moved.isEmpty)
    }

    @Test func `Changed confirmation revision cannot execute an unseen batch`() async {
        let ops = RecordingQueueOperations()
        let queue = QueueFixtures.queue(operations: ops)
        queue.registerInventory(QueueFixtures.scan([QueueFixtures.file("a"), QueueFixtures.file("b")]), origin: .files)
        _ = queue.add(paths: ["/fixture/a"], origin: .files)
        let approved = queue.snapshot.revision
        _ = queue.add(paths: ["/fixture/b"], origin: .files)
        await #expect(throws: ReviewQueueError.self) { try await queue.execute(expectedRevision: approved) }
        #expect(queue.snapshot.lastRun == nil && queue.snapshot.items.count == 2)
        #expect(await ops.moved.isEmpty)
    }

    @Test func `One invalid file blocks the complete batch before any mutation`() async throws {
        let ops = RecordingQueueOperations(invalidPath: "/fixture/b")
        let queue = QueueFixtures.queue(operations: ops)
        queue.registerInventory(QueueFixtures.scan([QueueFixtures.file("a"), QueueFixtures.file("b")]), origin: .files)
        _ = queue.add(paths: ["/fixture/a", "/fixture/b"], origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(await ops.moved.isEmpty)
        #expect(queue.snapshot.lastRun?.outcomes.allSatisfy { $0.status == .blocked } == true)
        #expect(queue.snapshot.items.allSatisfy { $0.requiresRescan })
    }

    @Test func `Partial Trash failures report each item and require fresh review for retries`() async throws {
        let ops = RecordingQueueOperations(failedTrash: "/fixture/b")
        let queue = QueueFixtures.queue(operations: ops)
        let scan = QueueFixtures.scan([QueueFixtures.file("a"), QueueFixtures.file("b"), QueueFixtures.file("c")])
        queue.registerInventory(scan, origin: .files)
        _ = queue.add(paths: Set(scan.files.map(\.path)), origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.movedCount == 2)
        #expect(queue.snapshot.lastRun?.outcomes.map(\.status) == [.moved, .failed, .moved])
        #expect(queue.snapshot.items.map(\.id) == ["/fixture/b"])
        #expect(queue.snapshot.blockers["/fixture/b"] != nil)
        #expect(queue.add(paths: ["/fixture/a"], origin: .files).rejections.count == 1)
    }

    @Test func `Cancellation and concurrent edits cannot replace the frozen executing batch`() async throws {
        let ops = RecordingQueueOperations(pauses: true)
        let active = QueueFixtures.queue(operations: ops)
        active.registerInventory(QueueFixtures.scan([QueueFixtures.file("a")]), origin: .files)
        _ = active.add(paths: ["/fixture/a"], origin: .files)
        let revision = active.snapshot.revision
        let task = Task { try await active.execute(expectedRevision: revision) }
        await ops.waitUntilStarted()
        #expect(active.snapshot.isExecuting)
        #expect(active.add(paths: ["/fixture/b"], origin: .files).rejections.count == 1)
        active.clear(); active.remove(path: "/fixture/a")
        #expect(active.snapshot.isExecuting && active.snapshot.items.count == 1)
        task.cancel(); await ops.finish(); try await task.value
        #expect(!active.snapshot.isExecuting && active.snapshot.lastRun?.outcomes.first?.status == .cancelled)
        #expect(await ops.moved.isEmpty)
    }
}

extension ReviewQueueTests {
    @Test func `Verified copies move while the kept copy remains protected after completion`() async throws {
        let ops = RecordingQueueOperations()
        let queue = QueueFixtures.queue(operations: ops)
        let kept = QueueFixtures.file("a"), b = QueueFixtures.file("b"), c = QueueFixtures.file("c")
        queue.registerDuplicates([DuplicateGroup(id: "digest", original: kept, duplicates: [b, c])], root: QueueFixtures.root)
        #expect(queue.add(paths: [b.path, c.path], origin: .duplicates).addedCount == 2)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.movedCount == 2 && queue.snapshot.items.isEmpty)
        #expect(await ops.moved == [b.path, c.path])
        #expect(await ops.constraintCalls == 3)
        queue.registerInventory(QueueFixtures.scan([kept]), origin: .files)
        #expect(queue.add(paths: [kept.path], origin: .files).rejections.count == 1)
    }

    @Test func `Queued duplicate protections survive a later scan in a different scope`() {
        let queue = QueueFixtures.queue()
        let kept = QueueFixtures.file("a"), copy = QueueFixtures.file("b")
        queue.registerDuplicates([DuplicateGroup(id: "digest", original: kept, duplicates: [copy])], root: QueueFixtures.root)
        _ = queue.add(paths: [copy.path], origin: .duplicates)
        queue.registerDuplicates([], root: URL(fileURLWithPath: "/other"))
        queue.registerInventory(QueueFixtures.scan([kept]), origin: .map)
        #expect(queue.add(paths: [kept.path], origin: .map).rejections.count == 1)
    }

    @Test func `Version conflicts and capacity limits never replace the reviewed selection`() {
        let queue = QueueFixtures.queue(limit: 2)
        let scan = QueueFixtures.scan([QueueFixtures.file("a"), QueueFixtures.file("b"), QueueFixtures.file("c")])
        queue.registerInventory(scan, origin: .files)
        let result = queue.add(paths: Set(scan.files.map(\.path)), origin: .files)
        #expect(result.addedCount == 2 && result.rejections.count == 1)
        queue.registerInventory(QueueFixtures.scan([QueueFixtures.file("a", bytes: 999)]), origin: .map)
        #expect(queue.add(paths: ["/fixture/a"], origin: .map).rejections.count == 1)
        #expect(queue.snapshot.items.first?.file.bytes == 100)
    }
}

extension ReviewQueueTests {
    @Test func `Duplicate protection identities remain distinct when paths contain delimiter characters`() {
        let first = DuplicateGroup(id: "digest", original: QueueFixtures.file("a|/fixture/b"), duplicates: [QueueFixtures.file("c")])
        let second = DuplicateGroup(id: "digest", original: QueueFixtures.file("a"), duplicates: [QueueFixtures.file("b|/fixture/c")])
        #expect(ReviewDuplicateProtection(group: first, root: QueueFixtures.root).id != ReviewDuplicateProtection(group: second, root: QueueFixtures.root).id)
    }
}


extension ReviewQueueTests {
    @Test func `A fresh retry after partial success does not require an already trashed group member`() async throws {
        let operations = RecordingQueueOperations(failedTrash: "/fixture/c")
        let queue = QueueFixtures.queue(operations: operations)
        let kept = QueueFixtures.file("a"), b = QueueFixtures.file("b"), c = QueueFixtures.file("c")
        queue.registerDuplicates([DuplicateGroup(id: "digest", original: kept, duplicates: [b, c])], root: QueueFixtures.root)
        _ = queue.add(paths: [b.path, c.path], origin: .duplicates)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.movedCount == 1)
        queue.remove(path: c.path)
        queue.registerInventory(QueueFixtures.scan([c]), origin: .files)
        _ = queue.add(paths: [c.path], origin: .files)
        try await queue.execute(expectedRevision: queue.snapshot.revision)
        #expect(queue.snapshot.lastRun?.outcomes.first?.status == .failed)
        #expect(await operations.moved == [b.path])
    }
}
