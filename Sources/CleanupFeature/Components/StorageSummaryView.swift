import StorageFixDesignSystem
import SwiftUI

struct StorageSummaryView: View {
    let availableBefore: String
    let availableAfter: String
    let reclaimed: String
    let cleanable: String
    let selected: String
    let remainingCleanable: String
    let hasRemainingCleanable: Bool
    let successMessage: String?
    let hasCleanupSummary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.large) {
                if hasCleanupSummary {
                    StorageMetricView(
                        title: "Available Before",
                        value: availableBefore,
                        systemImage: "internaldrive",
                        isHighlighted: false
                    )
                    Divider()
                    StorageMetricView(
                        title: "Space Reclaimed",
                        value: reclaimed,
                        systemImage: "sparkles",
                        isHighlighted: true
                    )
                    Divider()
                    StorageMetricView(
                        title: "Available After",
                        value: availableAfter,
                        systemImage: "checkmark.circle",
                        isHighlighted: false
                    )
                    if hasRemainingCleanable {
                        Divider()
                        StorageMetricView(
                            title: "Remaining Cleanable",
                            value: remainingCleanable,
                            systemImage: "tray.full",
                            isHighlighted: false
                        )
                    }
                } else {
                    StorageMetricView(
                        title: "Available Storage",
                        value: availableAfter,
                        systemImage: "internaldrive",
                        isHighlighted: false
                    )
                    Divider()
                    StorageMetricView(
                        title: "Cleanable Space",
                        value: cleanable,
                        systemImage: "sparkles",
                        isHighlighted: false
                    )
                    Divider()
                    StorageMetricView(
                        title: "Selected",
                        value: selected,
                        systemImage: "checkmark.circle",
                        isHighlighted: true
                    )
                }
            }
            if hasCleanupSummary, let successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.success)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(DesignSystem.Colors.accentSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .fixedSize(horizontal: false, vertical: true)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(
                    DesignSystem.Colors.accentBorder,
                    lineWidth: DesignSystem.Size.border
                )
        }
    }
}
