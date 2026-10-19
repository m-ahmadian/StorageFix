import AppKit
import Combine
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI
import WorkspaceFeature

/// The free-space menu bar item, built on NSStatusItem and NSPopover so updating it never touches the app's scenes.
@MainActor
final class StatusItemController: NSObject {
    static let visibilityKey = "storagefix.menuBar.visible"
    private static var installed: StatusItemController?

    private let monitor: FreeSpaceMonitor
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var subscriptions: Set<AnyCancellable> = []

    /// Installs the item once per launch; later calls do nothing.
    static func install(monitor: FreeSpaceMonitor, workspace: WorkspaceViewModel, folderAccess: FolderAccessSession, openMain: @escaping () -> Void) {
        guard installed == nil else { return }
        installed = StatusItemController(monitor: monitor, workspace: workspace, folderAccess: folderAccess, openMain: openMain)
    }

    static var isVisiblePreference: Bool { UserDefaults.standard.object(forKey: visibilityKey) as? Bool ?? true }

    private init(monitor: FreeSpaceMonitor, workspace: WorkspaceViewModel, folderAccess: FolderAccessSession, openMain: @escaping () -> Void) {
        self.monitor = monitor
        super.init()
        popover.behavior = .transient
        let menu = FreeSpaceMenuView(monitor: monitor, workspace: workspace, openMain: { [weak self] in
            self?.popover.performClose(nil); openMain()
        }, hide: { UserDefaults.standard.set(false, forKey: StatusItemController.visibilityKey) })
            .environment(\.folderAccessSession, folderAccess)
        popover.contentViewController = NSHostingController(rootView: menu)
        monitor.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateButton() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyVisibility() }.store(in: &subscriptions)
        applyVisibility()
    }

    private func applyVisibility() {
        let visible = Self.isVisiblePreference
        if visible, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(togglePopover(_:))
            item.button?.imagePosition = .imageLeading
            self.item = item
            updateButton()
        } else if !visible, let item {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func updateButton() {
        guard let button = item?.button else { return }
        let symbol = monitor.isLow ? "externaldrive.badge.exclamationmark" : "internaldrive"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Free space")
        button.title = " " + monitor.title
        button.toolTip = "StorageFix: \(monitor.title) free"
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown { popover.performClose(sender); return }
        monitor.refresh()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
