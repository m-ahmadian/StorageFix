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
                Text("macOS keeps apps out of your Library unless you allow it. Choose your Home folder\(homeName) and StorageFix will measure only known, rebuildable caches. Nothing is removed until you review and confirm. Access ends when you quit.")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Choose Home Folder…", systemImage: "house") { choose() }
                    .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.isLoading)
            }
            Spacer(minLength: DesignSystem.Spacing.none)
        }
        .padding(DesignSystem.Spacing.large).workspaceCard()
    }

    private var homeName: String { viewModel.requiredFolder.map { " (\($0.path))" } ?? "" }

    private func choose() {
        guard let folder = FolderPicker.choose(access: folderAccess, startingAt: viewModel.requiredFolder?.deletingLastPathComponent(),
            message: "Select your Home folder\(homeName) to allow cache cleanup.", prompt: "Allow") else { return }
        Task { await viewModel.grantAccess(to: folder) }
    }
}
