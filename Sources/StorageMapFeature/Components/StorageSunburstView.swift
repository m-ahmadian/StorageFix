import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct StorageSunburstView: View {
    @ObservedObject var viewModel: StorageMapViewModel
    var body: some View {
        ZStack {
            ForEach(viewModel.sunburstSegments) { segment in
                let wedge = SunburstWedge(segment: segment)
                Button { viewModel.activateSunburst(segment) } label: {
                    wedge.fill(DesignSystem.Colors.storageMapItem(at: segment.colorIndex).opacity(
                        segment.isOuter ? DesignSystem.Opacity.mapOuter : DesignSystem.Opacity.full))
                        .overlay { wedge.stroke(!segment.isOuter && viewModel.isSliceSelected(segment.slice.id) ? DesignSystem.Colors.primaryText : DesignSystem.Colors.card, lineWidth: DesignSystem.Size.mapSelectionBorder) }
                }
                .buttonStyle(.plain).contentShape(wedge)
                .accessibilityAddTraits(!segment.isOuter && viewModel.isSliceSelected(segment.slice.id) ? .isSelected : [])
                .accessibilityLabel(segment.slice.name)
                .accessibilityValue(viewModel.sunburstDetail(segment))
                .accessibilityHint(segment.isOuter ? "Open the parent folder and select this item" : "Select this item in the list")
                .help(viewModel.sunburstDetail(segment))
            }
        }.frame(width: DesignSystem.Size.sunburstChart, height: DesignSystem.Size.sunburstChart)
    }
}

private struct SunburstWedge: Shape {
    let segment: StorageSunburstSegment
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY), radius = min(rect.width, rect.height) / 2
        let inner = radius * (segment.isOuter ? DesignSystem.Chart.sunburstMiddle : DesignSystem.Chart.sunburstHole)
        let outer = radius * (segment.extendsToEdge ? DesignSystem.Chart.sunburstOuter : DesignSystem.Chart.sunburstMiddle)
        let start = Angle.degrees(segment.startFraction * DesignSystem.Chart.fullTurn + DesignSystem.Chart.topOrigin)
        let end = Angle.degrees(segment.endFraction * DesignSystem.Chart.fullTurn + DesignSystem.Chart.topOrigin)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addLine(to: CGPoint(x: center.x + inner * cos(end.radians), y: center.y + inner * sin(end.radians)))
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
