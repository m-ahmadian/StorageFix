import AppKit
import StorageFixDesignSystem
import SwiftUI
import WorkspaceFeature

/// The small panel under the menu bar item: free space at a glance and a shortcut to scan.
struct FreeSpaceMenuView: View {
    @ObservedObject var monitor: FreeSpaceMonitor
    @ObservedObject var workspace: WorkspaceViewModel
    let hide: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: DesignSystem.Brand.symbol).foregroundStyle(DesignSystem.Colors.accent)
                Text("StorageFix").font(.headline)
                Spacer()
                Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh")
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text("\(monitor.title) free").font(.title2.weight(.semibold))
                Text("of \(monitor.capacityTitle) · \(Int((monitor.usedFraction * 100).rounded()))% used")
                    .font(.caption).foregroundStyle(.secondary)
                ShareBar(value: Int64(monitor.usedFraction * 1000), total: 1000,
                         color: monitor.isLow ? DesignSystem.Colors.warning : DesignSystem.Colors.accent)
                if monitor.isLow {
                    Label("Your disk is getting full.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(DesignSystem.Colors.warning)
                }
            }
            Button {
                showMainWindow()
                workspace.select(.overview)
                if workspace.canReview { workspace.startReview() }
            } label: { Label("Scan My Mac", systemImage: "sparkles").frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryButtonStyle()).disabled(workspace.isBusy)
            Button("Open StorageFix") { showMainWindow() }.buttonStyle(.borderless)
            Divider()
            HStack {
                Button("Hide from Menu Bar", action: hide).buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless)
            }.font(.caption)
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: 280)
        .onAppear { monitor.refresh() }
    }

    private func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
