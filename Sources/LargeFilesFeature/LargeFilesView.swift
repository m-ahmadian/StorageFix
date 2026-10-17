import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct LargeFilesView: View {
    @Environment(\.folderAccessSession) private var folderAccess

    @ObservedObject private var vm: LargeFilesViewModel
    @State private var scanTask: Task<Void, Never>?
    public init(viewModel: LargeFilesViewModel) { vm = viewModel }
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FeatureHeading("Large & old files", subtitle: "A fresh look at your downloads, projects and forgotten exports.") {
                Button("Choose Folder…", systemImage: "folder") { if let folder = FolderPicker.choose(access: folderAccess) { vm.chooseFolder(folder) } }.disabled(vm.isLoading || vm.isQueueBusy)
                Button(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise") { scanTask = Task { await vm.scan() } }
                    .disabled(vm.isLoading || vm.isQueueBusy || vm.needsFolder).keyboardShortcut("r", modifiers: .command)
            }
            Label(vm.scope.path, systemImage: "folder").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            HStack(spacing: 18) {
                IconBadge("doc.text.magnifyingglass", color: DesignSystem.Colors.lilac)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vm.visibleFiles.count) \(vm.visibleFiles.count == 1 ? "file matches" : "files match") your filters").font(.headline)
                    Text("Largest first · dates refer to last modification").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: vm.visibleFiles.reduce(0) { $0 + $1.bytes }, countStyle: .file)).font(.system(size: 28, weight: .semibold)).monospacedDigit()
            }.padding(20).workspaceCard()
            VStack(spacing: 10) {
                TextField("Search by name or path", text: $vm.query).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("Size", selection: $vm.minimumMB) { Text("10 MB+").tag(10); Text("100 MB+").tag(100); Text("1 GB+").tag(1_000) }
                    Picker("Type", selection: $vm.kind) { ForEach(FileKind.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Age", selection: $vm.age) { ForEach(FileAge.allCases) { Text($0.rawValue).tag($0) } }
                }
            }
            if vm.isLoading {
                HStack { ProgressView().controlSize(.small); Text(vm.isRemoving ? "Checking files and moving to Trash…" : "Measuring files…"); Spacer(); if !vm.isRemoving { Button("Cancel") { scanTask?.cancel() } } }
            }
            if let error = vm.errorMessage { ReviewNotice(error, isError: true) }
            if let result = vm.resultMessage { ReviewNotice(result) }
            if let result = vm.queueAddResult { QueueAddResultView(result: result) }
            if let summary = vm.coverageSummary { InventoryCoverageView(summary: summary) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.visibleFiles.isEmpty && !vm.isLoading {
                        ContentUnavailableView(vm.hasScanned ? "Nothing matches these filters" : "Find the files you can let go",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(vm.hasScanned ? "Lower the size limit, clear the filters, or choose another folder." : "Start with Downloads or choose a folder. Scanning won’t change anything."))
                    }
                    ForEach(vm.visibleFiles) { file in
                        HStack(spacing: 14) {
                            Toggle("Select \(file.path) for Trash", isOn: Binding(get: { vm.selectedPaths.contains(file.path) }, set: { vm.setSelected(file.path, selected: $0) })).labelsHidden().toggleStyle(.checkbox).disabled(file.isSharedLink || !vm.canSelectFiles)
                            Image(systemName: "doc").font(.title2).foregroundStyle(DesignSystem.Colors.lilac)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(URL(fileURLWithPath: file.path).lastPathComponent).font(.headline)
                                Text(file.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).help(file.path)
                                if file.isSharedLink { Text("Shared hard link · inspect in Finder").font(.caption) }
                                if let date = file.modifiedAt { Text("Modified \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file)).monospacedDigit()
                            Button("Show", systemImage: "arrow.up.forward") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)]) }.help("Show in Finder")
                        }.padding(16).disabled(vm.isLoading || vm.isQueueBusy)
                        Divider().padding(.leading, 16)
                    }
                }.workspaceCard()
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(vm.selectedPaths.count) \(vm.selectedPaths.count == 1 ? "file" : "files") selected · \(ByteCountFormatter.string(fromByteCount: vm.selectedBytes, countStyle: .file))").font(.headline)
                    Text("Selections stay selected when filters change. Review all before moving to Trash.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear") { vm.clearSelection() }.disabled(vm.selectedPaths.isEmpty || vm.isLoading || vm.isQueueBusy)
                Button(vm.usesReviewQueue ? "Add to Review Queue" : "Review Selected", systemImage: vm.usesReviewQueue ? "tray.badge.plus" : "trash", action: vm.reviewSelected).buttonStyle(PrimaryButtonStyle()).disabled(vm.selectedPaths.isEmpty || vm.isLoading || vm.isQueueBusy)
            }.padding(18).workspaceCard()
        }.padding(28).background(DesignSystem.Colors.background)
        .sheet(isPresented: $vm.showsConfirmation) { reviewSheet }
        .onDisappear { if !vm.isRemoving { scanTask?.cancel() } }
    }
    private var reviewSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review files for Trash").font(.title2.bold())
            Text("Restore files in Finder until you empty Trash. Space is freed when Trash is emptied.").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(vm.files.filter { vm.selectedPaths.contains($0.path) }) { file in
                        HStack { Text(file.path).font(.callout).textSelection(.enabled); Spacer(); Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file)) }
                        Divider()
                    }
                }
            }.frame(maxHeight: 260)
            HStack { Button("Cancel") { vm.showsConfirmation = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Move \(vm.selectedPaths.count) \(vm.selectedPaths.count == 1 ? "File" : "Files") to Trash", role: .destructive) { Task { await vm.moveToTrash() } }.disabled(vm.isLoading || vm.isQueueBusy) }
        }.padding(28).frame(width: 640)
    }
}
