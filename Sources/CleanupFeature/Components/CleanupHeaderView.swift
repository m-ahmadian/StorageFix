import AppKit
import StorageFixDesignSystem
import SwiftUI

struct CleanupHeaderView: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            IconBadge("leaf")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text("Cleanup")
                    .font(.system(size: 30, weight: .semibold))
                Text("Review caches and optional data before permanently removing selected files.")
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
        }
    }
}
