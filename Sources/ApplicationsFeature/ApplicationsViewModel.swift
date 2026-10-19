import Foundation
import StorageFixCore

@MainActor
public final class ApplicationsViewModel: ObservableObject {
    @Published public private(set) var applications: [InstalledApplication] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRemoving = false
    @Published public private(set) var hasScanned = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public var query = ""
    @Published public var selectedApplication: InstalledApplication?
    public let permitsRemoval: Bool
    @Published public private(set) var needsFolder: Bool
    @Published public private(set) var scopeDescription: String
    @Published public private(set) var relatedFiles: [RelatedFile] = []
    @Published public private(set) var selectedRelated: Set<String> = []
    @Published public private(set) var isFindingRelated = false
    @Published public private(set) var relatedError: String?
    private var service: any ApplicationServiceProtocol
    private let related: (any AppRelatedFilesProviding)?
    private let runningBundleIDs: @Sendable () async -> Set<String>
    public init(service: any ApplicationServiceProtocol, permitsRemoval: Bool = true, requiresFolderSelection: Bool = false,
                related: (any AppRelatedFilesProviding)? = nil,
                runningBundleIDs: @escaping @Sendable () async -> Set<String> = { await WorkspaceRunningApplications().runningBundleIdentifiers() }) {
        self.service = service; self.permitsRemoval = permitsRemoval; needsFolder = requiresFolderSelection
        self.related = related; self.runningBundleIDs = runningBundleIDs
        scopeDescription = requiresFolderSelection ? "Choose an applications folder to grant read access" : "/Applications and your user Applications folder"
    }
    public func chooseFolder(_ folder: URL) {
        guard !isLoading else { return }
        service = ApplicationService(roots: [folder], permitsRemoval: permitsRemoval)
        needsFolder = false; scopeDescription = folder.path; applications = []; hasScanned = false
        errorMessage = nil; resultMessage = nil; selectedApplication = nil
    }
    public var visibleApplications: [InstalledApplication] { applications.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query) } }
    public var totalBytes: Int64 { applications.reduce(0) { $0 + $1.bytes } }
    public func scan() async {
        guard !isLoading else { return }
        guard !needsFolder else { errorMessage = "Choose an applications folder before scanning."; return }
        isLoading = true; errorMessage = nil; resultMessage = nil; applications = []; hasScanned = false
        defer { isLoading = false }
        do { applications = try await service.scan(); try Task.checkCancellation(); hasScanned = true }
        catch is CancellationError { applications = [] }
        catch { errorMessage = error.localizedDescription }
    }
    /// Leftover lookup is available when the Library can be read (always outside the sandbox, after the Home Allow inside it).
    public var findsRelatedFiles: Bool { related != nil }
    /// The review sheet can open: to uninstall (direct edition) or to remove an app's data (both editions).
    public var canReview: Bool { permitsRemoval || findsRelatedFiles }
    public var selectedRelatedFiles: [RelatedFile] { relatedFiles.filter { selectedRelated.contains($0.path) } }
    public var selectedRelatedBytes: Int64 { selectedRelatedFiles.reduce(0) { $0 + $1.bytes } }

    /// Opens the review for one app and looks up its leftovers. Items found by bundle identifier start selected;
    /// items matched only by name never do.
    public func review(_ app: InstalledApplication) async {
        guard canReview, !isLoading else { return }
        selectedApplication = app; relatedFiles = []; selectedRelated = []; relatedError = nil
        guard let related else { return }
        isFindingRelated = true
        defer { if selectedApplication == app { isFindingRelated = false } }
        do {
            let files = try await related.relatedFiles(bundleID: app.bundleIdentifier, appName: app.name)
            guard selectedApplication == app else { return }
            relatedFiles = files; selectedRelated = Set(files.filter { !$0.matchedByName }.map(\.path))
        } catch { if selectedApplication == app { relatedError = error.localizedDescription } }
    }

    public func setRelated(_ path: String, _ selected: Bool) {
        guard relatedFiles.contains(where: { $0.path == path }) else { return }
        if selected { selectedRelated.insert(path) } else { selectedRelated.remove(path) }
    }

    public func cancelReview() { selectedApplication = nil; relatedFiles = []; selectedRelated = []; isFindingRelated = false; relatedError = nil }

    /// Moves the app (direct edition) and the chosen leftovers to the Trash. Refused while the app is running.
    public func moveToTrash() async {
        guard !isLoading, let app = selectedApplication, applications.contains(app) else { return }
        let files = selectedRelatedFiles
        guard permitsRemoval || !files.isEmpty else { return }
        if await runningBundleIDs().contains(app.bundleIdentifier) {
            errorMessage = "Quit \(app.name) first, then try again."; cancelReview(); return
        }
        cancelReview(); isLoading = true; isRemoving = true; errorMessage = nil; resultMessage = nil
        defer { isLoading = false; isRemoving = false }
        do {
            if permitsRemoval {
                try await service.moveToTrash(app)
                applications.removeAll { $0.id == app.id }
            }
            let failed = await related?.moveToTrash(files) ?? []
            let moved = files.count - failed.count
            let size = ByteCountFormatter.string(fromByteCount: files.filter { !failed.contains($0.path) }.reduce(0) { $0 + $1.bytes }, countStyle: .file)
            let items = "\(moved) related \(moved == 1 ? "item" : "items") (\(size))"
            resultMessage = permitsRemoval
                ? "Moved \(app.name)\(moved > 0 ? " and \(items)" : "") to Trash. Restore them in Finder if needed."
                : "Moved \(items) of \(app.name) to Trash. The app stays installed and starts fresh next time."
            if !failed.isEmpty { errorMessage = "\(failed.count) related \(failed.count == 1 ? "item" : "items") could not be moved." }
        } catch { errorMessage = error.localizedDescription }
    }
}
