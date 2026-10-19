import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

/// One set of look-alike photos side by side. The suggested photo is marked Best but is never preselected.
struct SimilarPhotoGroupCard: View {
    let group: SimilarPhotoGroup
    @ObservedObject var viewModel: SimilarPhotosViewModel
    let reveal: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text("\(group.photos.count) similar photos").font(.headline)
                Spacer()
                Text("\(viewModel.size(group.extraBytes)) in extras").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            ScrollView(.horizontal) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(group.photos) { photo in tile(photo) }
                }.padding(.bottom, DesignSystem.Spacing.xSmall)
            }
        }
        .padding(DesignSystem.Spacing.medium).workspaceCard()
    }

    private func tile(_ photo: SimilarPhoto) -> some View {
        let selected = viewModel.isSelected(photo.path)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
            PhotoThumbnail(path: photo.path)
                .frame(width: 168, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.red.opacity(0.8) : .clear, lineWidth: 3))
                .overlay(alignment: .topLeading) {
                    if photo.path == group.suggestedKeep {
                        Text("Best").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(DesignSystem.Colors.accent).foregroundStyle(DesignSystem.Brand.foreground).clipShape(Capsule()).padding(6)
                    }
                }
                .onTapGesture(count: 2) { reveal(photo.path) }
            Toggle(isOn: Binding(get: { selected }, set: { viewModel.setSelected(photo.path, $0) })) {
                Text(URL(fileURLWithPath: photo.path).lastPathComponent).font(.caption).lineLimit(1).truncationMode(.middle)
            }.toggleStyle(.checkbox).frame(width: 168, alignment: .leading)
            Text("\(photo.pixelWidth)×\(photo.pixelHeight) · \(viewModel.size(photo.bytes))")
                .font(.caption2).foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .help(photo.path)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(URL(fileURLWithPath: photo.path).lastPathComponent), \(photo.pixelWidth) by \(photo.pixelHeight)\(photo.path == group.suggestedKeep ? ", suggested to keep" : "")")
    }
}
