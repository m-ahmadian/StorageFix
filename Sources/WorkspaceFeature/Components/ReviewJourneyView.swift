import StorageFixDesignSystem
import SwiftUI

/// Shows where the person is in choose → understand → inspect → queue → verify. Read-only guidance.
struct ReviewJourneyView: View {
    let journey: ReviewJourney
    let guidance: String
    let actionTitle: String?
    let action: (WorkspaceSection) -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: () -> Void = {}

    private static let markerSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.xSmall) {
                ForEach(JourneyStage.allCases) { stage in
                    marker(stage)
                    if stage != JourneyStage.allCases.last { connector(stage) }
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(guidance).font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let secondaryTitle { Button(secondaryTitle, systemImage: "doc.text", action: secondaryAction) }
                if let actionTitle, let stage = journey.current {
                    Button(actionTitle) { action(stage.section) }.buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding(DesignSystem.Spacing.medium).workspaceCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Review journey")
    }

    private func marker(_ stage: JourneyStage) -> some View {
        let complete = journey.isComplete(stage), current = journey.current == stage
        return HStack(spacing: DesignSystem.Spacing.xSmall) {
            ZStack {
                Circle().fill(complete || current ? DesignSystem.Colors.accent : DesignSystem.Colors.groupHeader)
                if complete {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(DesignSystem.Brand.foreground)
                } else {
                    Text("\(stage.rawValue + 1)").font(.caption2.weight(.semibold))
                        .foregroundStyle(current ? DesignSystem.Brand.foreground : DesignSystem.Colors.secondaryText)
                }
            }.frame(width: Self.markerSize, height: Self.markerSize).accessibilityHidden(true)
            Text(stage.title).font(.caption.weight(current ? .semibold : .regular))
                .foregroundStyle(current ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stage.rawValue + 1) of \(JourneyStage.allCases.count), \(stage.title)")
        .accessibilityValue(complete ? "Done" : current ? "Current step" : "Not started")
    }

    private func connector(_ stage: JourneyStage) -> some View {
        Rectangle().fill(journey.isComplete(stage) ? DesignSystem.Colors.accentBorder : DesignSystem.Colors.border)
            .frame(height: 1).frame(minWidth: DesignSystem.Spacing.small, maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
