import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct DuplicateView: View {
    @Environment(\.folderAccessSession) private var folderAccess

    private enum Sort: String, CaseIterable, Identifiable {
        case size = "Copy size", name = "Name", type = "File type"
        var id: String { rawValue }
    }
    @ObservedObject private var vm: DuplicateViewModel
    @State private var sort: Sort = .size
    @State private var query = ""
    @State private var scanTask: Task<Void, Never>?
    public init(viewModel: DuplicateViewModel) { vm = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find duplicates").font(.system(size: 30, weight: .semibold))
                    Text("Compare contents, choose a copy to keep, then review what goes to Trash.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose Folder…", systemImage: "folder") { chooseFolder() }.disabled(vm.isLoading || vm.isQueueBusy)
                Button(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise") {
                    scanTask = Task { await vm.scan() }
                }.disabled(vm.isLoading || vm.isQueueBusy || vm.needsFolder).keyboardShortcut("r", modifiers: .command)
            }
            Label(vm.scopeDescription, systemImage: "folder").font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack(spacing: 24) {
                Label("\(vm.groups.count) matching \(vm.groups.count == 1 ? "set" : "sets")", systemImage: "doc.on.doc")
                Label("\(vm.selectedPaths.count) copies selected", systemImage: "checkmark.circle")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: vm.selectedBytes, countStyle: .file)).font(.title2.bold())
            }.padding(20).workspaceCard()
            if vm.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(vm.isRemoving ? "Checking files and moving copies to Trash…" : "Reading and comparing file contents…")
                    Spacer()
                    if !vm.isRemoving { Button("Cancel") { scanTask?.cancel() } }
                }.padding(.vertical, 8)
            }
            if let error = vm.errorMessage { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled) }
            if let result = vm.resultMessage { Label(result, systemImage: "info.circle").foregroundStyle(.secondary) }
            if let result = vm.queueAddResult { QueueAddResultView(result: result) }
            if !vm.groups.isEmpty {
                HStack {
                    TextField("Filter by name or path", text: $query).textFieldStyle(.roundedBorder)
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 210)
                    Button(vm.selectedPaths.count == vm.duplicateCount ? "Deselect All" : "Select Copies") { vm.toggleSelectAll() }.disabled(vm.isLoading || vm.isQueueBusy)
                }
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.groups.isEmpty && !vm.isLoading {
                        ContentUnavailableView(vm.hasScanned ? "No duplicates found" : "Choose where to look",
                            systemImage: vm.hasScanned ? "checkmark.circle" : "doc.on.doc",
                            description: Text(vm.hasScanned ? "No matching nonempty files in this folder. Try another location." : "Scan your personal folders or choose a folder. Hidden files, app bundles and hard links are skipped. Nothing changes during a scan."))
                    } else if visibleGroups.isEmpty && !vm.isLoading {
                        ContentUnavailableView.search(text: query)
                    }
                    ForEach(visibleGroups) { group in
                        DuplicateCard(group: group, selected: vm.selectedPaths, reveal: vm.reveal, keep: vm.keep, select: vm.setSelected, preview: vm.preview, canPreview: vm.canPreview, suggestion: vm.suggestion(in: group))
                            .disabled(vm.isLoading || vm.isQueueBusy)
                    }
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("One copy always stays.").font(.headline)
                    Text("Trash is reversible until you empty it in Finder.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(vm.usesReviewQueue ? "Add to Review Queue" : "Review \(vm.selectedPaths.count) Copies", systemImage: vm.usesReviewQueue ? "tray.badge.plus" : "trash", action: vm.reviewSelected)
                    .buttonStyle(PrimaryButtonStyle()).disabled(vm.selectedPaths.isEmpty || vm.isLoading || vm.isQueueBusy)
            }.padding(16).workspaceCard()
        }.padding(28)
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $vm.showsConfirmation) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Review duplicate copies for Trash").font(.title2.bold())
                Text("All selected paths are shown, including copies hidden by filters. At least one copy stays in each set. Changed files require a rescan.").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.selectedFiles) { file in
                            HStack(alignment: .top) {
                                Text(file.path).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                            }
                            Divider()
                        }
                    }
                }.frame(maxHeight: 260)
                Text("Restore files in Finder until you empty Trash. Space is freed when Trash is emptied.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { vm.showsConfirmation = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Move \(vm.selectedPaths.count) \(vm.selectedPaths.count == 1 ? "Copy" : "Copies") to Trash", role: .destructive) { Task { await vm.remove() } }.disabled(vm.isLoading || vm.selectedPaths.isEmpty)
                }
            }.padding(28).frame(width: 640)
        }
        .onDisappear { if !vm.isRemoving { scanTask?.cancel() } }
    }

    private var visibleGroups: [DuplicateGroup] {
        vm.groups.filter { query.isEmpty || ([$0.original] + $0.duplicates).contains { $0.path.localizedCaseInsensitiveContains(query) } }.sorted {
            switch sort {
            case .size: return $0.original.bytes * Int64($0.duplicates.count) > $1.original.bytes * Int64($1.duplicates.count)
            case .name: return URL(fileURLWithPath: $0.original.path).lastPathComponent.localizedStandardCompare(URL(fileURLWithPath: $1.original.path).lastPathComponent) == .orderedAscending
            case .type: return URL(fileURLWithPath: $0.original.path).pathExtension.localizedStandardCompare(URL(fileURLWithPath: $1.original.path).pathExtension) == .orderedAscending
            }
        }
    }
    private func chooseFolder() {
        if let folder = FolderPicker.choose(access: folderAccess) { query = ""; vm.chooseFolder(folder) }
    }
}

