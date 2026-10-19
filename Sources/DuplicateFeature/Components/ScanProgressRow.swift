import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

/// Determinate progress while comparing, indeterminate while listing files or moving copies to Trash.
struct ScanProgressRow: View {
    let progress: DuplicateScanProgress?
    let isRemoving: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                if let fraction = progress?.fraction { Text("\(Int((fraction * 100).rounded()))%").font(.callout).monospacedDigit() }
            }
            if let fraction = progress?.fraction {
                ShareBar(value: Int64(fraction * 1000), total: 1000, color: DesignSystem.Colors.accent)
            } else {
                ProgressView().progressViewStyle(.linear).tint(DesignSystem.Colors.accent)
            }
            Text("You can switch to other screens; the scan keeps running.").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                .opacity(isRemoving ? 0 : 1)
        }
        .padding(DesignSystem.Spacing.medium).workspaceCard()
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if isRemoving { return "Checking files and moving copies to Trash…" }
        guard let progress, progress.phase == .comparing else { return "Listing files…" }
        return progress.total == 0 ? "No files of the same size to compare." : "Comparing \(progress.completed) of \(progress.total) same-size files…"
    }
}
