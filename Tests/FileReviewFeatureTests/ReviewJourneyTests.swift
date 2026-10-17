import Foundation
import ReviewQueueFeature
import StorageFixCore
import Testing
@testable import WorkspaceFeature

@MainActor struct ReviewJourneyTests {
    @Test func `Given no results, then the journey starts at choose and nothing is complete`() {
        let journey = ReviewJourney(ReviewJourney.Inputs())
        #expect(journey.current == .choose && !journey.isComplete(.choose))
    }

    @Test func `Queued files take precedence and earlier steps read as complete`() {
        let journey = ReviewJourney(ReviewJourney.Inputs(hasResults: true, queuedCount: 2, lastRunDate: Date()))
        #expect(journey.current == .queue && journey.isComplete(.inspect) && !journey.isComplete(.verify))
    }

    @Test func `An operation is verified only by a review that finishes after it`() {
        let run = Date(timeIntervalSince1970: 200)
        #expect(ReviewJourney(.init(hasResults: true, lastRunDate: run, lastReviewDate: Date(timeIntervalSince1970: 100))).current == .verify)
        #expect(ReviewJourney(.init(hasResults: true, lastRunDate: run)).current == .verify)
        let verified = ReviewJourney(.init(hasResults: true, lastRunDate: run, lastReviewDate: Date(timeIntervalSince1970: 300)))
        #expect(verified.current == nil && verified.isComplete(.verify))
    }

    @Test func `Given a workspace, when a person reviews, explores, queues, moves and rescans, then each stage advances`() async {
        let queue = featureQueue()
        let queueVM = ReviewQueueViewModel(queue: queue)
        let vm = fixtureWorkspace(queue: queueVM)
        #expect(vm.journey.current == .choose)
        await vm.review()
        #expect(vm.journey.current == .understand && vm.journeyActionTitle == "Open Storage Map")
        vm.select(.map)
        #expect(vm.journey.current == .inspect)
        let fixture = QueueFeatureFiles()
        queue.registerInventory(InventoryScan(sessionID: UUID(), root: fixture.root, options: InventoryOptions(), files: fixture.files), origin: .files)
        _ = queue.add(paths: [fixture.files[0].path], origin: .files)
        #expect(vm.journey.current == .queue && vm.journeyGuidance.contains("1 file is waiting"))
        queueVM.requestConfirmation(); await queueVM.execute()
        #expect(vm.journey.current == .verify && vm.journeyGuidance.contains("empty Trash"))
        vm.select(.overview); await vm.review()
        #expect(vm.journey.current == nil)
    }

    @Test func `Exploring before any results does not skip ahead, and choosing a folder resets exploration`() async {
        let vm = fixtureWorkspace()
        vm.select(.map)
        #expect(vm.journey.current == .choose)
        vm.select(.overview); await vm.review(); vm.select(.files)
        #expect(vm.journey.current == .inspect)
        vm.chooseReviewFolder(URL(fileURLWithPath: "/fixture"))
        #expect(!vm.hasExplored && vm.journey.current != .inspect)
    }
}
