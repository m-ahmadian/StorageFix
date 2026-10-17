import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

/// Diverging bars for the top-level folders that changed most between baseline and current scan.
struct FolderChangesView: View {
    @ObservedObject var viewModel: ScanComparisonViewModel
    private static let barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Folders that changed most").font(.headline)
            ForEach(viewModel.folderChanges) { change in row(change) }
            Text("Observed logical sizes only. Growth is not proof of new data, and shrinkage is not recovered space.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }

    private func row(_ change: ScanFolderChange) -> some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Text(viewModel.folderTitle(change)).font(.callout).lineLimit(1).truncationMode(.middle)
                .frame(width: DesignSystem.Size.folderChangeLabel, alignment: .leading).help(viewModel.folderTitle(change))
            GeometryReader { proxy in
                let half = proxy.size.width / 2
                let fraction = viewModel.largestFolderChange > 0 ? CGFloat(change.byteChange.magnitude) / CGFloat(viewModel.largestFolderChange) : 0
                let width = max(fraction * half, change.byteChange == 0 ? 0 : 2)
                ZStack(alignment: .leading) {
                    Rectangle().fill(DesignSystem.Colors.border).frame(width: 1).offset(x: half)
                    Capsule().fill(change.byteChange >= 0 ? DesignSystem.Colors.amber : DesignSystem.Colors.accent)
                        .frame(width: width, height: Self.barHeight)
                        .offset(x: change.byteChange >= 0 ? half : half - width)
                }.frame(maxHeight: .infinity)
            }.frame(height: Self.barHeight * 2).accessibilityHidden(true)
            Text(viewModel.signedSize(change.byteChange)).font(.callout.monospacedDigit().weight(.medium))
                .frame(width: DesignSystem.Size.folderChangeValue, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.folderTitle(change))
        .accessibilityValue("\(viewModel.signedSize(change.byteChange)) across \(change.changedPaths) changed \(change.changedPaths == 1 ? "path" : "paths")")
    }
}
