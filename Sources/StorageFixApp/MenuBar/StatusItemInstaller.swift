import AppKit
import StorageFixCore
import SwiftUI
import WorkspaceFeature

/// Invisible helper in the main window that installs the menu bar item once and lets it reopen the window.
struct StatusItemInstaller: View {
    let monitor: FreeSpaceMonitor
    let workspace: WorkspaceViewModel
    let folderAccess: FolderAccessSession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear.frame(width: 0, height: 0).accessibilityHidden(true).onAppear {
            let open = openWindow
            StatusItemController.install(monitor: monitor, workspace: workspace, folderAccess: folderAccess) {
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) { window.makeKeyAndOrderFront(nil) } else { open(id: "main") }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
