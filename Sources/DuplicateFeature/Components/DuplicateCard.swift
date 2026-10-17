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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            if let suggestion {
                Label(suggestion, systemImage: "lightbulb").font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            row(group.original, isCopy: false)
            Divider()
            ForEach(group.duplicates) { row($0, isCopy: true) }
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }
    private func row(_ file: DuplicateFile, isCopy: Bool) -> some View {
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
                Text(file.path).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .lineLimit(2).textSelection(.enabled).help(file.path)
                if let date = file.modifiedAt { Text("Modified \(date.formatted())").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small) {
                Text("\(isCopy ? "Copy" : "Kept") · \(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))")
                    .font(.caption.weight(.medium)).monospacedDigit()
                HStack(spacing: DesignSystem.Spacing.small) {
                    Button("Quick Look") { preview(file.path) }.disabled(!canPreview)
                    Button("Finder") { reveal(file.path) }.help("Show \(file.path) in Finder")
                    if isCopy { Button("Keep This") { keep(file.path, group.id) } }
                }.buttonStyle(.borderless)
            }
        }
    }
}
