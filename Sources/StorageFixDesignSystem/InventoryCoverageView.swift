import StorageFixCore
import SwiftUI

public struct InventoryCoverageView: View {
    private let summary: InventorySummary
    public init(summary: InventorySummary) { self.summary = summary }

    public var body: some View {
        DisclosureGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text(summary.sizeDetail)
                    Text(summary.volumeDetail)
                    Text("Counts describe observed entries, not the contents of skipped folders. Hard links share storage and are counted once. Cloud placeholders are skipped without opening their contents.")
                    ForEach(summary.reasonDetails, id: \.self) { Text($0) }
                    ForEach(summary.examples, id: \.self) { Text($0).textSelection(.enabled) }
                }.font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, DesignSystem.Spacing.small)
            }.frame(maxHeight: DesignSystem.Size.coverageDetailsHeight)
        } label: {
            Text(summary.title).font(.callout.weight(.semibold)).foregroundStyle(DesignSystem.Colors.primaryText)
        }
        .padding(DesignSystem.Spacing.medium).workspaceCard()
        .accessibilityHint("Expand for size definitions, volume capacity and skipped entries")
    }
}
