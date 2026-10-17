import Combine
import Foundation
import StorageFixCore

public enum FileKind: String, CaseIterable, Identifiable {
    case all = "All types", documents = "Documents", images = "Images", video = "Video", audio = "Audio", archives = "Archives", other = "Other"
    public var id: String { rawValue }
    public static func kind(of path: String) -> FileKind {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "pdf", "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "csv": .documents
        case "jpg", "jpeg", "png", "heic", "gif", "tif", "tiff", "webp", "raw", "svg": .images
        case "mov", "mp4", "m4v", "mkv", "avi", "webm": .video
        case "mp3", "m4a", "wav", "aiff", "flac": .audio
        case "zip", "dmg", "pkg", "gz", "tar", "7z", "rar": .archives
        default: .other
        }
    }
}
public enum FileAge: String, CaseIterable, Identifiable {
    case any = "Any age", sixMonths = "Modified 6+ months ago", year = "Modified 1+ year ago"
    public var id: String { rawValue }
    var months: Int? { switch self { case .any: nil; case .sixMonths: 6; case .year: 12 } }
}

@MainActor
public final class LargeFilesViewModel: ObservableObject {
    @Published public private(set) var files: [DuplicateFile] = []
    @Published public private(set) var selectedPaths: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRemoving = false
    @Published public private(set) var hasScanned = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public private(set) var scope: URL
    @Published public var query = ""
    @Published public var minimumMB = 100
    @Published public var kind: FileKind = .all
    @Published public var age: FileAge = .any
    @Published public var showsConfirmation = false
    @Published public private(set) var needsFolder: Bool
    @Published public private(set) var inventoryResult: InventoryScan?
    @Published public private(set) var queueAddResult: ReviewQueueAddResult?
    let queue: (any ReviewQueueProtocol)?
    private var queueSubscription: AnyCancellable?
    private let service: any FileBrowserServiceProtocol
    public init(scope: URL, service: any FileBrowserServiceProtocol, requiresFolderSelection: Bool = false, queue: (any ReviewQueueProtocol)? = nil) {
        self.scope = scope; self.service = service; needsFolder = requiresFolderSelection; self.queue = queue
        queueSubscription = queue?.finishedRuns.sink { [weak self] _ in self?.invalidateAfterQueue() }
    }
    public var usesReviewQueue: Bool { queue != nil }
    public var isQueueBusy: Bool { queue?.snapshot.isExecuting == true }
    public func reviewSelected() {
        if usesReviewQueue { addSelectedToQueue() } else { showsConfirmation = true }
    }
    private func addSelectedToQueue() {
        guard !isLoading, !isQueueBusy, let queue else { return }
        let result = queue.add(paths: selectedPaths, origin: .files)
        queueAddResult = result; resultMessage = result.message + " Open Review Queue to continue."
        if result.rejections.isEmpty { selectedPaths = [] }
    }
    private func invalidateAfterQueue() {
        files = []; selectedPaths = []; hasScanned = false; inventoryResult = nil; queueAddResult = nil
        resultMessage = "Queue operation finished. Scan again to refresh file review."
    }
    public var canSelectFiles: Bool { inventoryResult?.wasCancelled != true && inventoryResult?.volume?.isReadOnly != true }
    public var coverageSummary: InventorySummary? { inventoryResult.map(InventorySummary.init) }
    public var visibleFiles: [DuplicateFile] { filteredFiles(now: Date()) }
    public func filteredFiles(now: Date) -> [DuplicateFile] {
        let cutoff = age.months.flatMap { Calendar.current.date(byAdding: .month, value: -$0, to: now) }
        return files.filter { file in
            file.bytes >= Int64(minimumMB) * 1_000_000
                && (query.isEmpty || file.path.localizedCaseInsensitiveContains(query))
                && (kind == .all || FileKind.kind(of: file.path) == kind)
                && (cutoff == nil || (cutoff.map { limit in file.modifiedAt.map { $0 < limit } ?? false } ?? true))
        }
    }
    public var selectedBytes: Int64 { files.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.bytes } }
    public func chooseFolder(_ folder: URL) {
        guard !isLoading, !isQueueBusy else { return }
        needsFolder = false
        inventoryResult = nil
        scope = folder.resolvingSymlinksInPath(); files = []; hasScanned = false; errorMessage = nil; resultMessage = nil; selectedPaths = []
    }
    public func setSelected(_ path: String, selected: Bool) {
        guard !isLoading, !isQueueBusy, canSelectFiles, files.contains(where: { $0.path == path && !$0.isSharedLink }) else { return }
        if selected { selectedPaths.insert(path) } else { selectedPaths.remove(path) }
    }
    public func clearSelection() { if !isLoading { selectedPaths = [] } }
    public func scan() async {
        guard !isLoading, !isQueueBusy else { return }
        guard !needsFolder else { errorMessage = "Choose a folder to grant access before scanning."; return }
        inventoryResult = nil; queueAddResult = nil
        isLoading = true; errorMessage = nil; resultMessage = nil; files = []; hasScanned = false; selectedPaths = []
        defer { isLoading = false }
        do {
            let session = UUID()
            let result = try await service.inventory(in: scope, options: InventoryOptions(), sessionID: session, progress: { _ in })
            guard result.sessionID == session else { throw CancellationError() }
            if Task.isCancelled && !result.wasCancelled { throw CancellationError() }
            queue?.registerInventory(result, origin: .files)
            inventoryResult = result
            files = result.files
            hasScanned = true
            if result.wasCancelled {
                resultMessage = "Scan cancelled. Partial results remain for inspection. Scan again before selecting files."
            }
        } catch is CancellationError { files = []; resultMessage = "Scan cancelled. No files were changed." }
        catch { errorMessage = error.localizedDescription }
    }
    public func moveToTrash() async {
        if usesReviewQueue { showsConfirmation = false; addSelectedToQueue(); return }
        guard !isLoading, !selectedPaths.isEmpty else { return }
        showsConfirmation = false
        let paths = selectedPaths
        isLoading = true; isRemoving = true; errorMessage = nil; resultMessage = nil
        defer { isLoading = false; isRemoving = false }
        do {
            try await service.moveToTrash(paths: paths)
            resultMessage = "Moved \(paths.count) files to Trash. You can restore them in Finder. Scan again before another removal."
        } catch {
            errorMessage = "\(error.localizedDescription) Some files may already be in Trash. Scan again to refresh."
        }
        files = []; selectedPaths = []; hasScanned = false; inventoryResult = nil
    }
}
