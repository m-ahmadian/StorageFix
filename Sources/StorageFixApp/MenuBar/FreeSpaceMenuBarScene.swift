import StorageFixCore
import StorageFixDesignSystem
import SwiftUI
import WorkspaceFeature

/// The menu bar item as its own scene. Only its small label view observes free space, so a refresh never
/// re-evaluates the app's scenes or the main window.
struct FreeSpaceMenuBarScene: Scene {
    let monitor: FreeSpaceMonitor
    let workspace: WorkspaceViewModel
    let folderAccess: FolderAccessSession
    @AppStorage(FreeSpaceMenuBarScene.visibilityKey) private var isVisible = true
    static let visibilityKey = "storagefix.menuBar.visible"

    var body: some Scene {
        MenuBarExtra(isInserted: $isVisible) {
            FreeSpaceMenuView(monitor: monitor, workspace: workspace) { isVisible = false }
                .environment(\.folderAccessSession, folderAccess)
        } label: {
            FreeSpaceMenuLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

struct FreeSpaceMenuLabel: View {
    @ObservedObject var monitor: FreeSpaceMonitor
    var body: some View {
        Image(systemName: monitor.isLow ? "externaldrive.badge.exclamationmark" : "internaldrive")
        Text(monitor.title)
    }
}
