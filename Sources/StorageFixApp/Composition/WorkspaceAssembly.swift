import ApplicationsFeature
import CleanupFeature
import DuplicateFeature
import Foundation
import LargeFilesFeature
import ReviewQueueFeature
import ScanComparisonFeature
import StorageFixCore
import StorageMapFeature
import WorkspaceFeature

/// Own infrastructure at the app boundary. Feature view models receive protocols.
@MainActor enum WorkspaceAssembly {
    static func make(scriptURL: URL) -> WorkspaceViewModel {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appending(path: "Downloads").resolvingSymlinksInPath()
        let store = DistributionMode.current == .appStore
        let source = LocalInventoryMetadataSource()
        let inventory = FileInventoryService(source: source)
        let presenter = MacFilePresentationCoordinator()
        let protectedRoots = (ReviewFilePolicy.systemRoots.map { URL(fileURLWithPath: $0) }) + [home.appending(path: "Library")]
        let policy = ReviewFilePolicy(protectedRoots: protectedRoots)
        let comparisonSession = ScanComparisonSession()
        let comparison = ScanComparisonViewModel(session: comparisonSession, service: ScanSnapshotService())
        let volumes = VolumeInformationService(source: source)
        let queue = ReviewQueue(policy: policy, operations: ReviewFileOperations(policy: policy), volumes: volumes)
        let applications = store ? [] : [URL(fileURLWithPath: "/Applications"), home.appending(path: "Applications")]
        return WorkspaceViewModel(
            cleanup: CleanupViewModel(service: ScriptCleanupService(scriptURL: scriptURL)),
            duplicates: DuplicateViewModel(service: FileSystemDuplicateService(roots: [downloads]),
                scopeDescription: store ? "Choose a folder" : downloads.path, requiresFolderSelection: store, queue: queue, presenter: presenter),
            files: LargeFilesViewModel(scope: downloads, service: FileBrowserService(inventoryService: inventory), requiresFolderSelection: store, queue: queue),
            map: StorageMapViewModel(root: downloads, service: inventory, requiresFolderSelection: store, presenter: presenter, queue: queue, comparisonSession: comparisonSession),
            apps: ApplicationsViewModel(service: ApplicationService(roots: applications, permitsRemoval: !store),
                permitsRemoval: !store, requiresFolderSelection: store),
            volumeService: volumes, reviewQueue: ReviewQueueViewModel(queue: queue, presenter: presenter, reportService: QueueReportService()), scanComparison: comparison)
    }
}
