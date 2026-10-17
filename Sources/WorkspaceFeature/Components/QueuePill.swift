import StorageFixDesignSystem
import SwiftUI

/// Floating reminder of the shared Review Queue while inspecting files. Opening it never moves anything.
struct QueuePill: View {
    let summary: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "tray.full").accessibilityHidden(true)
                Text(summary).font(.callout.weight(.medium))
                Text("Review").font(.callout.weight(.semibold))
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
            }
            .foregroundStyle(DesignSystem.Brand.foreground)
            .padding(.horizontal, DesignSystem.Spacing.medium).padding(.vertical, DesignSystem.Spacing.small)
            .background(DesignSystem.Colors.accent, in: Capsule())
            .shadow(color: .black.opacity(DesignSystem.Opacity.pillShadow), radius: DesignSystem.Spacing.small, y: DesignSystem.Spacing.xSmall)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review Queue, \(summary)")
        .accessibilityHint("Opens the Review Queue. Nothing moves until you confirm there.")
    }
}
