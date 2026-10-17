import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct StorageTreemapView: View {
    @ObservedObject var viewModel: StorageMapViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(Array(StorageTreemap.cells(slices: viewModel.chartSlices).enumerated()), id: \.element.id) { index, cell in
                    Button { viewModel.selectSlice(cell.id) } label: {
                        ViewThatFits {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                Text(viewModel.sliceTitle(cell.slice)).font(.caption.weight(.semibold)).lineLimit(2)
                                Text(viewModel.sizeDescription(cell.slice.bytes)).font(.caption2).lineLimit(1)
                            }.padding(DesignSystem.Spacing.small)
                            Text(cell.slice.name).font(.caption2).padding(DesignSystem.Spacing.xSmall)
                            Color.clear
                        }
                        .frame(width: geometry.size.width * cell.width, height: geometry.size.height * cell.height)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .background(DesignSystem.Colors.storageMapItem(at: index).opacity(DesignSystem.Opacity.mapCell))
                        .overlay { Rectangle().stroke(viewModel.isSliceSelected(cell.id)
                            ? DesignSystem.Colors.accent : DesignSystem.Colors.card, lineWidth: DesignSystem.Size.mapSelectionBorder) }
                        .clipped()
                    }
                    .buttonStyle(.plain)
                    .position(x: geometry.size.width * (cell.x + cell.width / 2), y: geometry.size.height * (cell.y + cell.height / 2))
                    .accessibilityAddTraits(viewModel.isSliceSelected(cell.id) ? .isSelected : [])
                    .accessibilityLabel(viewModel.sliceTitle(cell.slice))
                    .accessibilityValue("\(viewModel.sizeDescription(cell.slice.bytes)), \(viewModel.shareDescription(cell.slice.bytes))")
                    .accessibilityHint("Select this area, then explore the folder or preview a file")
                    .help("\(cell.slice.name) · \(viewModel.sizeDescription(cell.slice.bytes)) · \(viewModel.shareDescription(cell.slice.bytes))")
                }
            }
        }
        .frame(width: DesignSystem.Size.treemapWidth, height: DesignSystem.Size.treemapHeight)
    }
}
