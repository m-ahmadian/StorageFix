import StorageFixDesignSystem
import SwiftUI

/// One-time permission step for the sandboxed edition: the person chooses their Home folder before caches are measured.
struct CleanupAccessCard: View {
    @Environment(\.folderAccessSession) private var folderAccess
    @ObservedObject var viewModel: CleanupViewModel

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            IconBadge("lock.open", color: DesignSystem.Colors.accent)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Allow cache cleanup").font(.headline)
                Text("macOS asks once before an App Store app can look inside your Library. Click Allow\(homeName) and StorageFix measures known, rebuildable caches. Nothing is removed until you review and confirm. You won't be asked again.")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow Cache Scan…", systemImage: "lock.open") { choose() }
                    .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.isLoading)
            }
            Spacer(minLength: DesignSystem.Spacing.none)
        }
        .padding(DesignSystem.Spacing.large).workspaceCard()
    }

    private var homeName: String { viewModel.requiredFolder.map { " (\($0.path))" } ?? "" }

    private func choose() {
        // The panel opens on Home itself, so clicking Allow grants it with no further navigation.
        guard let folder = FolderPicker.choose(access: folderAccess, startingAt: viewModel.requiredFolder,
            message: "Click Allow to let StorageFix scan caches in your Home folder\(homeName).", prompt: "Allow") else { return }
        Task {
            await viewModel.grantAccess(to: folder)
            if !viewModel.needsAccess { folderAccess?.remember(folder) }
        }
    }
}
