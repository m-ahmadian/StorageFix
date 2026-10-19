import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct CleanupCategoryRow: View {
    let category: CleanupCategory
    let sizeDescription: String
    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: DesignSystem.Size.rowIcon)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                    Text(category.name)
                        .font(.body)
                    if category.status == .blocked || category.status == .failed {
                        Label(category.message, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                    Text(category.items.isEmpty ? category.path : itemSummary)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                        .help(category.items.joined(separator: "\n"))
                    if category.movesToTrash {
                        Label("Moves to Trash", systemImage: "trash").font(.caption2).foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                Spacer()
                if category.warning.isEmpty == false {
                    Label(category.warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .lineLimit(1)
                        .help(category.warning)
                }
                Text(sizeDescription)
                    .font(.body)
                    .foregroundStyle(category.bytesAfter > 0 ? .primary : .secondary)
                    .fixedSize()
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .disabled(category.bytesAfter == 0)
        .help(helpText)
    }

    private var symbolName: String {
        switch category.id {
        case "xcode-derived-data", "xcode-doc-cache", "ios-device-support", "xcode-previews", "xcode-archives": "hammer"
        case "xcodebuildmcp-cache": "wrench.and.screwdriver"
        case "swiftpm-cache", "npm-cache", "node-gyp-cache", "gradle-cache", "cargo-cache", "bun-cache", "maven-repository", "cocoapods-repos": "shippingbox"
        case "google-cache": "globe"
        case "claude-cache": "bubble.left.and.text.bubble.right"
        case "adobe-cache": "paintbrush"
        case "adobe-media-cache": "film.stack"
        case "codex-runtime-cache": "terminal"
        case "user-cache-files": "folder.badge.gearshape"
        case "app-logs": "doc.text"
        case "simulator-contents", "simulator-caches", "ios-software-updates": "iphone"
        case "old-installers": "shippingbox.and.arrow.backward"
        case "app-leftovers": "puzzlepiece.extension"
        case "ollama-models", "huggingface-cache", "lmstudio-models": "cpu"
        default: "folder"
        }
    }

    private var itemSummary: String {
        let shown = category.items.prefix(3).joined(separator: ", ")
        let more = category.items.count - 3
        return more > 0 ? "\(shown) and \(more) more" : shown
    }

    private var helpText: String {
        if category.warning.isEmpty == false { return category.warning }
        if category.message.isEmpty == false { return category.message }
        return category.path
    }
}
