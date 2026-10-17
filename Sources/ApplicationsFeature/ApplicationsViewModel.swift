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
    private var service: any ApplicationServiceProtocol
    public init(service: any ApplicationServiceProtocol, permitsRemoval: Bool = true, requiresFolderSelection: Bool = false) {
        self.service = service; self.permitsRemoval = permitsRemoval; needsFolder = requiresFolderSelection
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
    public func moveToTrash() async {
        guard permitsRemoval, !isLoading, let app = selectedApplication, applications.contains(app) else { return }
        selectedApplication = nil; isLoading = true; isRemoving = true; errorMessage = nil; resultMessage = nil
        defer { isLoading = false }
        defer { isRemoving = false }
        do {
            try await service.moveToTrash(app)
            applications.removeAll { $0.id == app.id }
            resultMessage = "Moved \(app.name) to Trash. App documents and support data remain. Restore the app in Finder if needed."
        } catch { errorMessage = error.localizedDescription }
    }
}
