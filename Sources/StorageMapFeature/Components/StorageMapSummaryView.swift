import Charts
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct StorageMapSummaryView: View {
    @ObservedObject var viewModel: StorageMapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            if viewModel.mapStyle == .treemap { StorageTreemapView(viewModel: viewModel) }
            else if viewModel.mapStyle == .sunburst { StorageSunburstView(viewModel: viewModel) }
            else { ring }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text(viewModel.sizeDescription(viewModel.totalBytes)).font(.title.weight(.semibold)).monospacedDigit()
                Text("\(viewModel.items.count) items · logical file sizes")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                legend
                Text(viewModel.chartExplanation).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Logical sizes are not guaranteed recoverable space.").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }.padding(DesignSystem.Spacing.large).workspaceCard()
    }

    private var ring: some View {
        Chart(Array(viewModel.chartSlices.enumerated()), id: \.element.id) { index, slice in
                SectorMark(angle: .value("Logical size", slice.bytes),
                           innerRadius: .ratio(DesignSystem.Chart.storageMapRingRatio),
                           angularInset: DesignSystem.Chart.angularInset)
                    .foregroundStyle(DesignSystem.Colors.storageMapItem(at: index))
                    .cornerRadius(DesignSystem.Radius.chartSegment)
                    .opacity(viewModel.selectedID == nil || viewModel.isSliceSelected(slice.id)
                        ? DesignSystem.Opacity.full : DesignSystem.Opacity.mapDimmed)
            }
            .frame(width: DesignSystem.Size.storageMapChart, height: DesignSystem.Size.storageMapChart)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Folder size breakdown")
            .accessibilityValue(viewModel.chartAccessibilityValue)
            .chartAngleSelection(value: Binding(get: { viewModel.selectedAngle }, set: { viewModel.selectAngle($0) }))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
            ForEach(Array(viewModel.chartSlices.enumerated()), id: \.element.id) { index, slice in
                Button { viewModel.selectSlice(slice.id) } label: {
                    HStack(spacing: DesignSystem.Spacing.small) {
                    Circle().fill(DesignSystem.Colors.storageMapItem(at: index))
                        .frame(width: DesignSystem.Size.legendMarker, height: DesignSystem.Size.legendMarker)
                        .accessibilityHidden(true)
                    Text(viewModel.sliceTitle(slice)).lineLimit(1).help(viewModel.sliceTitle(slice))
                    Spacer()
                    Text(viewModel.sizeDescription(slice.bytes)).monospacedDigit()
                    Text(viewModel.shareDescription(slice.bytes)).monospacedDigit()
                    }.font(.caption).accessibilityElement(children: .combine)
                }.buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .fontWeight(viewModel.isSliceSelected(slice.id) ? .semibold : .regular)
                    .accessibilityAddTraits(viewModel.isSliceSelected(slice.id) ? .isSelected : [])
            }
        }
    }
}
