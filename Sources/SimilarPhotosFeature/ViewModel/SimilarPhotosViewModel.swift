import Foundation
import StorageFixCore

/// Finds look-alike photos in one folder and moves only the photos the person picks to the Trash.
/// Suggestions never select anything, and every group always keeps at least one photo.
@MainActor
public final class SimilarPhotosViewModel: ObservableObject {
    @Published public private(set) var groups: [SimilarPhotoGroup] = []
    @Published public private(set) var selectedPaths: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var progress: SimilarPhotoProgress?
    @Published public private(set) var hasScanned = false
    @Published public private(set) var analyzedCount = 0
    @Published public private(set) var wasLimited = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public private(set) var folder: URL?
    @Published public var showsConfirmation = false
    private let service: any SimilarPhotoServiceProtocol
    private let byteFormatter: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()

    public init(service: any SimilarPhotoServiceProtocol, folder: URL? = nil) {
        self.service = service; self.folder = folder
    }

    public var needsFolder: Bool { folder == nil }
    public var selectedPhotos: [SimilarPhoto] { groups.flatMap(\.photos).filter { selectedPaths.contains($0.path) } }
    public var selectedBytes: Int64 { selectedPhotos.reduce(0) { $0 + $1.bytes } }
    public var extraBytes: Int64 { groups.reduce(0) { $0 + $1.extraBytes } }
    public func size(_ bytes: Int64) -> String { byteFormatter.string(fromByteCount: bytes) }

    public func chooseFolder(_ folder: URL) {
        guard !isLoading else { return }
        self.folder = folder
        groups = []; selectedPaths = []; hasScanned = false; errorMessage = nil; resultMessage = nil
    }

    /// Uses a folder only when none was chosen yet (for example Pictures once Home access is allowed).
    public func offerDefaultFolder(_ folder: URL) { if self.folder == nil { chooseFolder(folder) } }

    public func scan() async {
        guard !isLoading else { return }
        guard let folder else { errorMessage = "Choose a folder of photos first."; return }
        isLoading = true; errorMessage = nil; resultMessage = nil; groups = []; selectedPaths = []; hasScanned = false
        progress = SimilarPhotoProgress(analyzed: 0, total: 0)
        defer { isLoading = false; progress = nil }
        do {
            let scan = try await service.scan(in: folder) { [weak self] value in
                Task { @MainActor in if self?.isLoading == true { self?.progress = value } }
            }
            try Task.checkCancellation()
            groups = scan.groups; analyzedCount = scan.analyzedCount; wasLimited = scan.wasLimited; hasScanned = true
        } catch is CancellationError {
            resultMessage = "Scan cancelled. No photos were changed."
        } catch { errorMessage = error.localizedDescription }
    }

    public func isSelected(_ path: String) -> Bool { selectedPaths.contains(path) }

    /// Selecting is refused when it would leave a group with no photo kept.
    public func setSelected(_ path: String, _ selected: Bool) {
        guard !isLoading, let group = groups.first(where: { $0.photos.contains { $0.path == path } }) else { return }
        if !selected { selectedPaths.remove(path); return }
        let remaining = group.photos.filter { !selectedPaths.contains($0.path) && $0.path != path }
        guard !remaining.isEmpty else { return }
        selectedPaths.insert(path)
    }

    /// The person's explicit choice: select every photo except the suggested one in each group.
    public func selectAllButBest() {
        guard !isLoading else { return }
        selectedPaths = Set(groups.flatMap { group in group.photos.map(\.path).filter { $0 != group.suggestedKeep } })
    }

    public func clearSelection() { selectedPaths = [] }

    public func requestTrash() {
        guard !isLoading, !selectedPaths.isEmpty else { return }
        showsConfirmation = true
    }

    public func confirmTrash() async {
        guard !isLoading, !selectedPaths.isEmpty else { return }
        showsConfirmation = false
        let photos = selectedPhotos
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        let failed = Set(await service.moveToTrash(photos))
        let moved = photos.filter { !failed.contains($0.path) }
        let movedPaths = Set(moved.map(\.path))
        groups = groups.compactMap { group in
            let left = group.photos.filter { !movedPaths.contains($0.path) }
            return left.count > 1 ? SimilarPhotoGroup(photos: left) : nil
        }
        selectedPaths = []
        let bytes = size(moved.reduce(0) { $0 + $1.bytes })
        resultMessage = "Moved \(moved.count) \(moved.count == 1 ? "photo" : "photos") (\(bytes)) to the Trash. Restore them from Finder if needed; space is freed when you empty the Trash."
        if !failed.isEmpty { errorMessage = "\(failed.count) \(failed.count == 1 ? "photo was" : "photos were") skipped because they changed or could not be moved. Scan again to refresh." }
    }
}
