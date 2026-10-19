import Foundation
import StorageFixCore

/// Lists what macOS starts automatically and points out items left behind by apps that are gone.
@MainActor
public final class LoginItemsViewModel: ObservableObject {
    @Published public private(set) var items: [LaunchItem] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasScanned = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var resultMessage: String?
    @Published public var pendingRemoval: LaunchItem?
    @Published public var showsLeftoversOnly = false
    private let service: any LaunchItemsProviding

    public init(service: any LaunchItemsProviding) { self.service = service }

    public var permitsRemoval: Bool { service.permitsRemoval }
    public var leftoverCount: Int { items.filter(\.isLeftover).count }
    public var visibleItems: [LaunchItem] { showsLeftoversOnly ? items.filter(\.isLeftover) : items }
    public func canRemove(_ item: LaunchItem) -> Bool { permitsRemoval && item.scope == .user }

    public func scan() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        items = await service.scan(); hasScanned = true
    }

    public func requestRemoval(_ item: LaunchItem) { if canRemove(item) { pendingRemoval = item } }

    public func confirmRemoval() async {
        guard let item = pendingRemoval, canRemove(item) else { return }
        pendingRemoval = nil; errorMessage = nil; resultMessage = nil
        do {
            try await service.moveToTrash(item)
            items.removeAll { $0.id == item.id }
            resultMessage = "Moved \(item.label) to Trash. It stops starting after you log out or restart."
        } catch { errorMessage = error.localizedDescription }
    }
}
