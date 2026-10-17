import StorageFixDesignSystem
import SwiftUI

struct StorageMetricView: View {
    let title: String
    let value: String
    let systemImage: String
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(
                    isHighlighted ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText
                )
                .frame(width: DesignSystem.Size.metricIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(isHighlighted ? DesignSystem.Colors.accent : .primary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
