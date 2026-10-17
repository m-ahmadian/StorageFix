import AppKit
import SwiftUI
import StorageFixCore

public struct FeatureHeading<Actions: View>: View {
    let title: String
    let subtitle: String
    let actions: Actions
    public init(_ title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
        self.title = title; self.subtitle = subtitle; self.actions = actions()
    }
    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 30, weight: .semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            HStack(spacing: 10) { actions }.padding(.top, 4)
        }
    }
}
public struct IconBadge: View {
    let symbol: String
    let color: Color
    public init(_ symbol: String, color: Color = DesignSystem.Colors.accent) { self.symbol = symbol; self.color = color }
    public var body: some View {
        Image(systemName: symbol).font(.system(size: 23, weight: .medium)).foregroundStyle(color)
            .frame(width: 52, height: 52).background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }
}
public struct ReviewNotice: View {
    let message: String
    let isError: Bool
    public init(_ message: String, isError: Bool = false) { self.message = message; self.isError = isError }
    public var body: some View {
        Label(message, systemImage: isError ? "exclamationmark.triangle" : "info.circle")
            .font(.callout).foregroundStyle(isError ? Color.primary : DesignSystem.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading).padding(DesignSystem.Spacing.medium)
            .background(isError ? DesignSystem.Colors.warningSurface : DesignSystem.Colors.accentSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control)).textSelection(.enabled)
    }
}
public extension View {
    func workspaceCard() -> some View {
        background(DesignSystem.Colors.card).clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay { RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.primary.opacity(0.055)) }
    }
}
public enum FolderPicker {
    @MainActor public static func choose(access: (any FolderAccessSessionProtocol)?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Tip: choose your Home folder to review Desktop, Documents and Downloads together. StorageFix does not keep access after you quit."
        guard panel.runModal() == .OK, let folder = panel.url else { return nil }
        guard let access else { return nil }
        access.retain(folder)
        return folder.resolvingSymlinksInPath()
    }
}
