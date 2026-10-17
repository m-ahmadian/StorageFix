import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct StorageMapView: View {
    @Environment(\.folderAccessSession) private var folderAccess

    @ObservedObject private var vm: StorageMapViewModel
    @State private var scanTask: Task<Void, Never>?

    public init(viewModel: StorageMapViewModel) { vm = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            heading
            navigation
            scanOptions
            status
            if let summary = vm.coverageSummary { InventoryCoverageView(summary: summary) }
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                if !vm.items.isEmpty {
                    ScrollView { StorageMapSummaryView(viewModel: vm) }
                        .frame(minHeight: DesignSystem.Spacing.none, maxHeight: .infinity)
                        .frame(width: DesignSystem.Size.mapSidebarMinWidth)
                    Divider()
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    selection
                    ScrollView { itemList }.frame(minHeight: DesignSystem.Spacing.none, maxHeight: .infinity)
                }.padding(.leading, DesignSystem.Spacing.small)
                    .frame(minHeight: DesignSystem.Spacing.none, maxHeight: .infinity)
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
            Text("Explore here; manage files in Finder. No files are changed by the storage map.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .padding(DesignSystem.Spacing.large)
        .frame(minWidth: DesignSystem.Spacing.none, maxWidth: .infinity,
               minHeight: DesignSystem.Spacing.none, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.background)
        .onDisappear { scanTask?.cancel() }
    }

    private var heading: some View {
        FeatureHeading("Storage map", subtitle: "See what fills a folder. Explore deeper without another scan.") {
            Button("Choose Folder…", systemImage: "folder") {
                if let folder = FolderPicker.choose(access: folderAccess) { vm.chooseFolder(folder) }
            }.disabled(vm.isLoading || vm.isQueueBusy)
            Button(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise") {
                scanTask = Task { await vm.scan() }
            }.disabled(vm.isLoading || vm.isQueueBusy || vm.needsFolder)
        }
    }

    private var scanOptions: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Toggle("Include hidden files", isOn: Binding(get: { vm.options.includesHiddenFiles }, set: { vm.setHiddenFiles($0) }))
            Toggle("Inspect package contents", isOn: Binding(get: { vm.options.includesPackageContents }, set: { vm.setPackageContents($0) }))
            Text("Read-only map options · apply on next scan").font(.caption)
        }.toggleStyle(.checkbox).disabled(vm.isLoading || vm.isQueueBusy)
    }

    private var navigation: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Button("Back", systemImage: "chevron.left", action: vm.back).disabled(!vm.canGoBack || vm.isLoading)
                ForEach(vm.breadcrumbs) { crumb in
                    Button(crumb.name) { vm.navigate(to: crumb) }.disabled(vm.isLoading || crumb.path == vm.current.path)
                        .help(crumb.path)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
            }
        }
    }

    private var selection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text(vm.selectionTitle).font(.callout.weight(.medium)).lineLimit(2)
            if let path = vm.selectionPath { Text(path).font(.caption).textSelection(.enabled).lineLimit(2).help(path) }
            HStack {
                Button("Explore", action: vm.exploreSelection).disabled(vm.selectedItem?.isFolder != true)
                if vm.usesReviewQueue {
                    Button("Add to Queue", action: vm.addSelectionToQueue).disabled(!vm.canQueueSelection)
                        .help("Choose individual files from a fresh standard scan. Hidden/package inspection and cancelled/read-only scans are inspection-only.")
                }
                Button("Quick Look", action: vm.previewSelection).disabled(!vm.canPreview).keyboardShortcut("y", modifiers: .command)
                Button("Show in Finder", action: vm.revealSelection).disabled(!vm.canReveal)
            }
            TextField("Filter this folder’s list", text: Binding(get: { vm.query }, set: { vm.setQuery($0) })).textFieldStyle(.roundedBorder)
            HStack(spacing: DesignSystem.Spacing.small) {
                Picker("Sort", selection: Binding(get: { vm.sort }, set: { vm.setSort($0) })) {
                    ForEach(MapSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Map style", selection: Binding(get: { vm.mapStyle }, set: { vm.setMapStyle($0) })) {
                    ForEach(MapStyle.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: DesignSystem.Size.mapStylePickerWidth)
            }
            Text("Search filters the list; the map continues to show the whole folder.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .disabled(vm.isLoading || vm.isQueueBusy)
        .focusable()
        .onMoveCommand { direction in vm.moveSelection(by: direction == .up || direction == .left ? -1 : 1) }
        .onKeyPress(.return) { vm.exploreSelection(); return .handled }
        .onKeyPress(.space) { vm.previewSelection(); return .handled }
    }

    @ViewBuilder private var status: some View {
        if vm.isLoading {
            HStack {
                ProgressView().controlSize(.small)
                Text(vm.progress.map { "Visited \($0.visitedCount) entries · \($0.fileCount) files" } ?? "Reading folder metadata…")
                Spacer()
                Button("Cancel") { scanTask?.cancel() }
            }
        }
        if let error = vm.errorMessage { ReviewNotice(error, isError: true) }
        if let message = vm.resultMessage { ReviewNotice(message) }
        if let result = vm.queueAddResult { QueueAddResultView(result: result) }
    }

    private var itemList: some View {
        LazyVStack(spacing: DesignSystem.Spacing.none) {
                if vm.visibleItems.isEmpty && !vm.isLoading {
                    ContentUnavailableView(vm.listEmptyTitle, systemImage: "chart.pie", description: Text(vm.listEmptyDescription))
                }
                ForEach(vm.visibleItems) { item in
                    itemRow(item, index: vm.colorIndex(for: item))
                    Divider().padding(.leading, DesignSystem.Spacing.medium)
                }

        }.workspaceCard()
    }

    private func itemRow(_ item: StorageMapItem, index: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            IconBadge(item.isFolder ? "folder" : "doc", color: DesignSystem.Colors.storageMapItem(at: index))
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Button(item.name) { vm.selectItem(item) }.buttonStyle(.plain).font(.headline).lineLimit(1).help(item.path)
                    .accessibilityAddTraits(vm.selectedID == .item(item.path) ? .isSelected : [])
                    .accessibilityHint("Select for Quick Look or folder exploration")
                ProgressView(value: Double(item.bytes), total: Double(max(1, vm.totalBytes)))
                    .tint(DesignSystem.Colors.storageMapItem(at: index))
                    .frame(maxWidth: DesignSystem.Size.storageMapProgressWidth)
                    .accessibilityLabel("Share of folder").accessibilityValue(vm.shareDescription(item.bytes))
                Text("\(item.fileCount) \(item.fileCount == 1 ? "file" : "files") · \(vm.shareDescription(item.bytes)) of this folder")
                    .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            Text(vm.sizeDescription(item.bytes)).font(.headline).monospacedDigit()
            Button("Show in Finder") {
                vm.reveal(item)
            }
            if item.isFolder { Button("Explore", systemImage: "chevron.right") { vm.enter(item) } }
        }.padding(DesignSystem.Spacing.medium)
            .background(vm.selectedID == .item(item.path) ? DesignSystem.Colors.accentSurface : DesignSystem.Colors.card)
    }
}
