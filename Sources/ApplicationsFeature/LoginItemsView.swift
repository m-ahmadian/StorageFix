import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct LoginItemsView: View {
    @ObservedObject private var vm: LoginItemsViewModel
    public init(viewModel: LoginItemsViewModel) { vm = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FeatureHeading("Login Items", subtitle: "What starts automatically with your Mac, and what was left behind by apps you removed.") {
                Button("Login Items Settings", systemImage: "gearshape") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
                }
                Button(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise") { Task { await vm.scan() } }.disabled(vm.isLoading)
            }
            HStack(spacing: 18) {
                IconBadge("power", color: DesignSystem.Colors.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(vm.items.count) background \(vm.items.count == 1 ? "item" : "items")").font(.headline)
                    Text(vm.leftoverCount == 0 ? "No leftovers found" : "\(vm.leftoverCount) left behind by apps that are gone")
                        .font(.caption).foregroundStyle(vm.leftoverCount == 0 ? Color.secondary : DesignSystem.Colors.warning)
                }
                Spacer()
                Toggle("Leftovers only", isOn: $vm.showsLeftoversOnly).toggleStyle(.switch).disabled(vm.leftoverCount == 0)
            }.padding(20).workspaceCard()
            if let error = vm.errorMessage { ReviewNotice(error, isError: true) }
            if let result = vm.resultMessage { ReviewNotice(result) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.visibleItems.isEmpty && !vm.isLoading {
                        ContentUnavailableView(vm.hasScanned ? "Nothing to show" : "See what starts with your Mac", systemImage: "power",
                            description: Text(vm.hasScanned ? "No background items match." : "Scan reads the launch agents and daemons on this Mac. Nothing is changed."))
                    }
                    ForEach(vm.visibleItems) { item in row(item); Divider().padding(.leading, 16) }
                }.workspaceCard()
            }
            ReviewNotice(vm.permitsRemoval
                ? "Only items for your own login can be moved to the Trash here. System items are shown for information; manage apps' own login items in Settings."
                : "This list is read-only. Show an item in Finder or open Login Items Settings to turn things off.")
        }
        .padding(28).background(DesignSystem.Colors.background)
        .task { if !vm.hasScanned { await vm.scan() } }
        .sheet(item: $vm.pendingRemoval) { item in
            VStack(alignment: .leading, spacing: 16) {
                Text("Move \(item.label) to Trash?").font(.title2.bold())
                Text(item.path).font(.caption.monospaced()).textSelection(.enabled)
                Text(item.isLeftover ? "The program it starts no longer exists, so it is safe to remove. It stops after you log out or restart."
                                     : "Its app may stop working in the background (for example updates or sync). It stops after you log out or restart; put it back from the Trash to undo.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Cancel") { vm.pendingRemoval = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Move to Trash", role: .destructive) { Task { await vm.confirmRemoval() } }
                }
            }.padding(28).frame(width: 520)
        }
    }

    private func row(_ item: LaunchItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.isLeftover ? "exclamationmark.triangle.fill" : "gearshape.2")
                .foregroundStyle(item.isLeftover ? DesignSystem.Colors.warning : DesignSystem.Colors.secondaryText).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label).font(.headline).lineLimit(1)
                Text([item.appName.map { "From \($0)" }, item.scope.rawValue, item.isLeftover ? "Program missing: left behind" : nil,
                      item.keepsAlive ? "Always running" : item.runsAtLoad ? "Starts at login" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(item.isLeftover ? DesignSystem.Colors.warning : .secondary)
                if let program = item.program { Text(program).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(program) }
            }
            Spacer()
            Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
            if vm.canRemove(item) { Button("Remove…", systemImage: "trash") { vm.requestRemoval(item) } }
        }.padding(14)
    }
}
