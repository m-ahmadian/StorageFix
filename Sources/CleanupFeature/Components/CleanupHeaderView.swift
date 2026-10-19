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
                Text("Review every category before cleaning. Caches are deleted; installers and leftovers go to the Trash.")
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
        }
    }
}
