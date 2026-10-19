import ApplicationsFeature
import CleanupFeature
import Combine
import DuplicateFeature
import Foundation
import LargeFilesFeature
import ReviewQueueFeature
import ScanComparisonFeature
import SimilarPhotosFeature
import StorageFixCore
import StorageMapFeature

public struct ActivityEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let detail: String
}
@MainActor
public final class WorkspaceViewModel: ObservableObject {
    @Published public private(set) var selectedSection: WorkspaceSection = .overview
    public let cleanup: CleanupViewModel
    public let duplicates: DuplicateViewModel
    public let files: LargeFilesViewModel
    public let map: StorageMapViewModel
    public let scanComparison: ScanComparisonViewModel?
    public let reviewQueue: ReviewQueueViewModel?
    public let apps: ApplicationsViewModel
    public let photos: SimilarPhotosViewModel?
    public let startup: LoginItemsViewModel?
    @Published public private(set) var isReviewing = false
    @Published public private(set) var reviewStep = ""
    @Published public private(set) var completedSteps = 0
    @Published public private(set) var lastReviewDate: Date?
    @Published public private(set) var latestReport: ReviewReport?
    @Published public private(set) var reviewMessage: String?
    @Published public private(set) var availableBytes: Int64?
    @Published public private(set) var capacityBytes: Int64?
    @Published public private(set) var activity: [ActivityEntry] = []
    @Published public private(set) var hasExplored = false
    /// A queue run the person has moved on from (new folder or a new review cycle); the journey no longer waits on it.
    @Published private(set) var acknowledgedRunID: UUID?
    public let edition: DistributionMode
    private var reviewTask: Task<Void, Never>?
    /// Cache cleanup exists in both editions; the sandboxed one first needs the Home folder granted.
    public var supportsCleanup: Bool { true }
    /// Caches join Quick Review once cleanup can measure them.
    public var reviewsCaches: Bool { !cleanup.needsAccess }
    /// Installed applications are measured automatically only outside the sandbox.
    public var reviewsApplications: Bool { edition == .direct }
    @Published public private(set) var includesDuplicateComparison: Bool
    public var reviewStageCount: Int { 1 + (includesDuplicateComparison ? 1 : 0) + (reviewsApplications ? 1 : 0) + (reviewsCaches ? 1 : 0) }
    private let volumeService: (any VolumeInformationServiceProtocol)?
    private let defaults: UserDefaults
    private var subscriptions: Set<AnyCancellable> = []
    public init(cleanup: CleanupViewModel, duplicates: DuplicateViewModel, files: LargeFilesViewModel,
                map: StorageMapViewModel, apps: ApplicationsViewModel, defaults: UserDefaults = .standard, edition: DistributionMode = .current, includesDuplicateComparison: Bool = false, volumeService: (any VolumeInformationServiceProtocol)? = nil, reviewQueue: ReviewQueueViewModel? = nil, scanComparison: ScanComparisonViewModel? = nil, autoReviewFolder: URL? = nil, photos: SimilarPhotosViewModel? = nil, autoPhotosFolder: URL? = nil, startup: LoginItemsViewModel? = nil) {
        self.photos = photos; self.startup = startup
        self.scanComparison = scanComparison
        self.reviewQueue = reviewQueue
        self.includesDuplicateComparison = includesDuplicateComparison
        self.volumeService = volumeService
        self.cleanup = cleanup; self.duplicates = duplicates; self.files = files; self.map = map; self.apps = apps; self.defaults = defaults; self.edition = edition
        if let data = defaults.data(forKey: "storagefix.activity.v1"), let entries = try? JSONDecoder().decode([ActivityEntry].self, from: data) { activity = Array(entries.prefix(12)) }
        var publishers = [cleanup.objectWillChange, duplicates.objectWillChange, files.objectWillChange, map.objectWillChange, apps.objectWillChange]
        if let scanComparison { publishers.append(scanComparison.objectWillChange) }
        if let photos { publishers.append(photos.objectWillChange) }
        if let startup { publishers.append(startup.objectWillChange) }
        if let reviewQueue {
            publishers.append(reviewQueue.objectWillChange)
            reviewQueue.$snapshot.compactMap(\.lastRun).removeDuplicates { $0.id == $1.id }
                .sink { [weak self] run in self?.finishQueueRun(run) }.store(in: &subscriptions)
        }
        for publisher in publishers {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        }
        cleanup.$resultMessage.compactMap { $0 }.filter { $0.hasPrefix("Cleanup") }.sink { [weak self] message in self?.record(title: "Cache cleanup", detail: message) }.store(in: &subscriptions)
        duplicates.$resultMessage.compactMap { $0 }.filter { $0.hasPrefix("Moved") }.sink { [weak self] message in self?.record(title: "Duplicate copies", detail: message) }.store(in: &subscriptions)
        files.$resultMessage.compactMap { $0 }.filter { $0.hasPrefix("Moved") }.sink { [weak self] message in self?.record(title: "File review", detail: message) }.store(in: &subscriptions)
        photos?.$resultMessage.compactMap { $0 }.filter { $0.hasPrefix("Moved") }.sink { [weak self] message in self?.record(title: "Similar photos", detail: message) }.store(in: &subscriptions)
        apps.$resultMessage.compactMap { $0 }.sink { [weak self] message in self?.record(title: "Application review", detail: message) }.store(in: &subscriptions)
        // Once the Home folder is allowed, review a sensible folder without asking the person to pick one.
        if let autoReviewFolder {
            cleanup.$needsAccess.filter { !$0 }.first().sink { [weak self] _ in
                guard let self, self.files.needsFolder else { return }
                self.chooseReviewFolder(autoReviewFolder)
            }.store(in: &subscriptions)
        }
        // Pictures becomes the photo folder as soon as Home access exists (at once in the direct edition).
        if let photos, let autoPhotosFolder {
            cleanup.$needsAccess.filter { !$0 }.first().sink { _ in photos.offerDefaultFolder(autoPhotosFolder) }.store(in: &subscriptions)
        }
    }
    public func setDuplicateComparison(_ included: Bool) { if !isBusy { includesDuplicateComparison = included } }
    public var canReview: Bool { !isBusy && !files.needsFolder }
    public var isBusy: Bool { reviewQueue?.isExecuting == true || isReviewing || cleanup.isLoading || duplicates.isLoading || files.isLoading || apps.isLoading || map.isLoading }
    public func select(_ section: WorkspaceSection) {
        guard !isReviewing, reviewQueue?.isExecuting != true, section != .cleanup || supportsCleanup else { return }
        if journey.current == nil { acknowledgedRunID = reviewQueue?.snapshot.lastRun?.id; hasExplored = false }
        if [.map, .files, .duplicates].contains(section), files.hasScanned || latestReport != nil { hasExplored = true }
        selectedSection = section
    }
    /// Opens Cleanup with the reviewed selection and asks for confirmation. Nothing is removed until confirmed there.
    public func reviewAndClean() {
        if isReviewing { stopReview(); isReviewing = false }
        guard !cleanup.isLoading, reviewQueue?.isExecuting != true, cleanup.hasScanned, cleanup.selectedBytes > 0 else { return }
        select(.cleanup)
        cleanup.requestCleanup()
    }
    public func refreshDisk() {
        let volume = volumeService?.volume(at: files.scope) ?? files.inventoryResult?.volume
        availableBytes = volume?.availableBytes; capacityBytes = volume?.capacityBytes
    }
    public func chooseReviewFolder(_ folder: URL) {
        guard !isBusy else { return }
        files.chooseFolder(folder); duplicates.chooseFolder(folder); map.chooseFolder(folder)
        Task { await cleanup.offerFolder(folder) }
        lastReviewDate = nil; latestReport = nil; reviewMessage = nil; completedSteps = 0; hasExplored = false
        acknowledgedRunID = reviewQueue?.snapshot.lastRun?.id
        refreshDisk()
    }
    /// Starts Quick Review owned by the view model, so other actions (Review & Clean) can stop it.
    public func startReview() {
        guard canReview else { return }
        reviewTask = Task { await review() }
    }
    /// First run in the sandbox: the one Allow click grants Home, then the review starts with no folder to pick.
    /// Returns false when the chosen folder was not Home.
    @discardableResult public func allowHomeAndReview(_ folder: URL) async -> Bool {
        await cleanup.offerFolder(folder)
        guard !cleanup.needsAccess else {
            reviewMessage = "Click Allow with your Home folder selected so StorageFix can scan it."
            return false
        }
        startReview()
        return true
    }
    /// True when the first click should ask for the Home folder instead of starting a review.
    public var needsHomeAllow: Bool { edition == .appStore && cleanup.needsAccess }
    /// Stops the review at once; a stage blocked on the filesystem is abandoned rather than awaited.
    public func stopReview() { reviewTask?.cancel(); reviewTask = nil }

    public func review() async {
        guard canReview else { return }
        isReviewing = true; completedSteps = 0; lastReviewDate = nil; latestReport = nil; reviewMessage = nil
        defer { isReviewing = false; reviewStep = "" }
        var results: [ReviewAreaResult] = []
        for (title, scan, result) in reviewOperations {
            guard !Task.isCancelled else { cancelReview(); return }
            reviewStep = title
            guard await ReviewStage.run(scan), !Task.isCancelled else { cancelReview(); return }
            results.append(result())
            completedSteps += 1
        }
        finishReview(results)
    }
    private var reviewOperations: [(String, @MainActor @Sendable () async -> Void, @MainActor () -> ReviewAreaResult)] {
        var operations: [(String, @MainActor @Sendable () async -> Void, @MainActor () -> ReviewAreaResult)] = []
        // Caches first: fast, and the cleanup report is ready while slower folder scans continue.
        if reviewsCaches {
            operations.append(("Measuring caches", { await self.cleanup.scan() }, {
                self.area(.cleanup, scope: "Allow-listed cache locations", count: self.cleanup.categories.count,
                          bytes: self.cleanup.cleanableBytes, error: self.cleanup.errorMessage)
            }))
        }
        operations.append(("Reviewing folder files", { await self.files.scan() }, {
                self.area(.files, scope: self.files.scope.path, count: self.files.files.count,
                          bytes: self.files.files.reduce(0) { $0 + $1.bytes }, error: self.files.errorMessage ?? (self.files.inventoryResult?.coverage.hasReadErrors == true ? "Partial inventory: some entries could not be measured. See file review coverage." : nil))
            }))
        if includesDuplicateComparison {
            operations.append(("Comparing duplicate contents", { await self.duplicates.scan() }, {
                self.area(.duplicates, scope: self.duplicates.scopeDescription, count: self.duplicates.duplicateCount,
                          bytes: self.duplicates.groups.flatMap(\.duplicates).reduce(0) { $0 + $1.bytes }, error: self.duplicates.errorMessage)
            }))
        }
        if reviewsApplications {
            operations.append(("Measuring applications", { await self.apps.scan() }, {
                self.area(.apps, scope: self.apps.scopeDescription, count: self.apps.applications.count,
                          bytes: self.apps.totalBytes, error: self.apps.errorMessage)
            }))
        }
        return operations
    }
    private func area(_ section: WorkspaceSection, scope: String, count: Int, bytes: Int64, error: String?) -> ReviewAreaResult {
        ReviewAreaResult(section: section, scope: scope, itemCount: error == nil ? count : nil,
                         bytes: error == nil ? bytes : nil, error: error)
    }
    private func finishReview(_ results: [ReviewAreaResult]) {
        if let inventory = files.inventoryResult { map.acceptInventory(inventory) }
        else if files.hasScanned { map.acceptInventory(files.files, root: files.scope) }
        let errors = results.filter { $0.error != nil }
        let date = Date()
        lastReviewDate = date; refreshDisk()
        latestReport = ReviewReport(date: date, folder: files.scope.path, areas: results,
                                    availableBytes: availableBytes, capacityBytes: capacityBytes)
        reviewMessage = errors.isEmpty ? "Your review is ready. Explore each area and choose what to keep." : "Review finished with \(errors.count) areas needing attention. Open the report for details."
        record(title: "Quick review", detail: "Reviewed \(results.count) areas; \(errors.count) need attention. No files changed.")
    }
    private func finishQueueRun(_ run: ReviewQueueRun) {
        latestReport = nil; lastReviewDate = nil
        refreshDisk()
        reviewMessage = "Queue finished: \(run.movedCount) of \(run.outcomes.count) files moved to Trash. Scan again for a fresh inventory."
        record(title: "Review Queue", detail: "\(run.movedCount) files moved; \(run.outcomes.count - run.movedCount) need a fresh review. No space-recovery estimate.")
    }

    private func cancelReview() {
        reviewMessage = "Review cancelled. No files were changed. Completed areas remain available; run Review Again for a full report."
    }
    public func clearActivity() {
        activity = []
        defaults.removeObject(forKey: "storagefix.activity.v1")
    }
    private func record(title: String, detail: String) {
        activity.insert(ActivityEntry(id: UUID(), date: Date(), title: title, detail: detail), at: 0)
        activity = Array(activity.prefix(12))
        if let data = try? JSONEncoder().encode(activity) { defaults.set(data, forKey: "storagefix.activity.v1") }
    }
}
