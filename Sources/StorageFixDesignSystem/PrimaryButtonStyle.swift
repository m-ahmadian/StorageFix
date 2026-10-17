import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .foregroundStyle(.white)
            .background(
                DesignSystem.Colors.accent.opacity(
                    !isEnabled ? 0.35 : (configuration.isPressed ? DesignSystem.Opacity.pressed : 1)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
    }
}
