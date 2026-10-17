import StorageFixDesignSystem
import SwiftUI

struct CleanupActionsView: View {
    let selectedSize: String
    let isLoading: Bool
    let canClean: Bool
    let rescan: () -> Void
    let clean: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Label {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                    Text("\(selectedSize) selected")
                        .font(.headline)
                    Text("Selected files are permanently removed. Review optional data warnings.")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            } icon: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Spacer()
            Button("Rescan", systemImage: "arrow.clockwise", action: rescan)
                .buttonStyle(.bordered)
                .disabled(isLoading)
            Button(isLoading ? "Working..." : "Clean Selected", action: clean)
                .buttonStyle(PrimaryButtonStyle())
                .frame(minWidth: DesignSystem.Size.actionButtonWidth)
                .disabled(isLoading || canClean == false)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(DesignSystem.Colors.card)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
