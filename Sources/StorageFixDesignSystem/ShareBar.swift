import SwiftUI

/// A thin share-of-total bar drawn in an explicit colour (linear ProgressView ignores tint on macOS).
public struct ShareBar: View {
    private let fraction: Double
    private let color: Color
    private static let height: CGFloat = 6

    public init(value: Int64, total: Int64, color: Color) {
        fraction = total > 0 ? min(1, max(0, Double(value) / Double(total))) : 0
        self.color = color
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignSystem.Colors.groupHeader)
                Capsule().fill(color).frame(width: max(fraction > 0 ? Self.height : 0, proxy.size.width * fraction))
            }
        }.frame(height: Self.height)
    }
}
