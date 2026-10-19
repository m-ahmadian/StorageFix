import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct ApplicationsView: View {
    @Environment(\.folderAccessSession) private var folderAccess

    @ObservedObject private var vm: ApplicationsViewModel
    @State private var scanTask: Task<Void, Never>?
    public init(viewModel: ApplicationsViewModel) { vm = viewModel }
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FeatureHeading("Applications", subtitle: "Find the apps taking up space. Keep what you use; review what you don’t.") {
                Button("Choose Folder…", systemImage: "folder") { if let folder = FolderPicker.choose(access: folderAccess) { vm.chooseFolder(folder) } }.disabled(vm.isLoading)
                Button("App Store Updates", systemImage: "arrow.up.forward") { if let url = URL(string: "macappstore://showUpdatesPage") { NSWorkspace.shared.open(url) } }
                Button(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise") { scanTask = Task { await vm.scan() } }.disabled(vm.isLoading || vm.needsFolder)
            }
            HStack(spacing: 18) {
                IconBadge("square.stack.3d.up", color: DesignSystem.Colors.amber)
                VStack(alignment: .leading, spacing: 5) { Text("\(vm.applications.count) \(vm.applications.count == 1 ? "application" : "applications")").font(.headline); Text(vm.scopeDescription).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: vm.totalBytes, countStyle: .file)).font(.system(size: 28, weight: .semibold)).monospacedDigit()
            }.padding(20).workspaceCard()
            TextField("Search applications", text: $vm.query).textFieldStyle(.roundedBorder)
            if vm.isLoading { HStack { ProgressView().controlSize(.small); Text(vm.isRemoving ? "Moving application to Trash…" : "Reviewing applications…"); Spacer(); if !vm.isRemoving { Button("Cancel Scan") { scanTask?.cancel() } } } }
            if let error = vm.errorMessage { ReviewNotice(error, isError: true) }
            if let result = vm.resultMessage { ReviewNotice(result) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.visibleApplications.isEmpty && !vm.isLoading {
                        ContentUnavailableView(vm.hasScanned ? "No matching applications" : "A simpler app collection", systemImage: "square.stack.3d.up",
                            description: Text(vm.hasScanned ? "Clear the search or scan again." : "Scan an applications folder to sort app bundles by disk usage. Scanning never changes your apps."))
                    }
                    ForEach(vm.visibleApplications) { application in
                        HStack(spacing: 16) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path)).resizable().frame(width: 42, height: 42).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(application.name).font(.headline)
                                Text("Version \(application.version) · \(application.bundleIdentifier)").font(.caption).foregroundStyle(.secondary)
                                Text(application.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).help(application.path)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: application.bytes, countStyle: .file)).monospacedDigit()
                            Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: application.path)]) }.help("Show in Finder")
                            if vm.canReview {
                                Button(vm.permitsRemoval ? "Uninstall…" : "App Data…", systemImage: vm.permitsRemoval ? "trash" : "externaldrive.badge.minus") {
                                    Task { await vm.review(application) }
                                }.disabled(vm.isLoading)
                            }
                        }.padding(16)
                        Divider().padding(.leading, 16)
                    }
                }.workspaceCard()
            }
            ReviewNotice(vm.permitsRemoval
                ? "Uninstall finds the app's settings, caches and support files too, so nothing is left behind. Everything goes to the Trash. Your documents are never touched."
                : vm.findsRelatedFiles ? "This edition doesn't uninstall apps. App Data… finds an app's settings and caches so you can reset it; remove the app itself from Finder."
                : "App inventory is read-only. Allow Home access in Cleanup to also find each app's settings and caches.")
        }.padding(28).background(DesignSystem.Colors.background)
        .sheet(item: $vm.selectedApplication) { application in AppRemovalSheet(application: application, vm: vm) }
        .onDisappear { scanTask?.cancel() }
    }
}
