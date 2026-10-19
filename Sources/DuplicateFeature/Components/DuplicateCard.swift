import Foundation
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct DuplicateCard: View {
    let group: DuplicateGroup
    let selected: Set<String>
    let reveal: (String) -> Void
    let keep: (String, String) -> Void
    let select: (String, Bool) -> Void
    let preview: (String) -> Void
    let canPreview: Bool
    let suggestion: String?
    var body: some View {
        let paths = ([group.original] + group.duplicates).map(\.path)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            if let suggestion {
                Label(suggestion, systemImage: "lightbulb").font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            row(group.original, isCopy: false, among: paths)
            Divider()
            ForEach(group.duplicates) { row($0, isCopy: true, among: paths) }
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }
    /// Folder path with the folders that differ between copies emphasised.
    private func highlightedFolder(_ path: String, among paths: [String]) -> Text {
        let parts = PathHighlight.make(for: path, among: paths)
        return Text(parts.shared).foregroundStyle(DesignSystem.Colors.secondaryText)
            + Text(parts.distinct).foregroundStyle(DesignSystem.Colors.accent).fontWeight(.semibold)
            + Text(URL(fileURLWithPath: path).lastPathComponent).foregroundStyle(DesignSystem.Colors.secondaryText)
    }
    private func row(_ file: DuplicateFile, isCopy: Bool, among paths: [String]) -> some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            if isCopy {
                Toggle("Select \(file.path) for review", isOn: Binding(get: { selected.contains(file.path) }, set: { select(file.path, $0) }))
                    .labelsHidden().toggleStyle(.checkbox)
            } else {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(DesignSystem.Colors.success)
                    .accessibilityLabel("Kept copy")
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text(URL(fileURLWithPath: file.path).lastPathComponent).fontWeight(isCopy ? .regular : .semibold)
                // Plain text: selectable text in long scrolling lists is very slow on macOS.
                highlightedFolder(file.path, among: paths).font(.caption)
                    .lineLimit(2).accessibilityLabel(file.path)
                if let date = file.modifiedAt { Text("Modified \(date.formatted())").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small) {
                Text("\(isCopy ? "Copy" : "Kept") · \(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))")
                    .font(.caption.weight(.medium)).monospacedDigit()
                HStack(spacing: DesignSystem.Spacing.small) {
                    Button("Quick Look") { preview(file.path) }.disabled(!canPreview)
                    Button("Finder") { reveal(file.path) }
                    if isCopy { Button("Keep This") { keep(file.path, group.id) } }
                }.buttonStyle(.borderless)
            }
        }
    }
}
