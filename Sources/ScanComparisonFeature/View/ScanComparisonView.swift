import StorageFixCore
import StorageFixDesignSystem
import SwiftUI
import UniformTypeIdentifiers

public struct ScanComparisonView: View {
    @ObservedObject private var vm: ScanComparisonViewModel
    @State private var task: Task<Void, Never>?
    @State private var isImporting = false
    @State private var isExporting = false
    public init(viewModel: ScanComparisonViewModel) { vm = viewModel }
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            FeatureHeading("Scan Comparison", subtitle: "Save a baseline, rescan, and understand what changed.") {
                Button("Open Baseline…", systemImage: "folder") { isImporting = true }.disabled(vm.isLoading)
                Button("Save Baseline…", systemImage: "square.and.arrow.up") { isExporting = true }.disabled(vm.exportText == nil || vm.isLoading)
            }
            Text(vm.scopeDescription).font(.callout).lineLimit(2).help(vm.scopeDescription).textSelection(.enabled)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Baseline").font(.headline)
                Text(vm.baselineDescription).font(.callout).lineLimit(2).help(vm.baselineDescription).textSelection(.enabled)
                if let warning = vm.baselineWarning { ReviewNotice(warning) }
                HStack {
                    Button("Use Current Scan as Baseline") { task = Task { await vm.captureBaseline() } }.disabled(!vm.canCapture)
                    Button("Compare with Current Scan") { task = Task { await vm.compare() } }.disabled(!vm.canCompare)
                    Button("Clear Baseline", action: vm.clearBaseline).disabled(vm.baseline == nil || vm.isLoading)
                }
            }.padding(DesignSystem.Spacing.medium).workspaceCard()
            Text("Saved snapshots contain the full folder path, relative file names, sizes, dates and coverage counts. No file contents or access permissions are saved. Keep snapshot files private.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            if vm.isLoading { HStack { ProgressView("Preparing comparison…"); Button("Cancel") { task?.cancel(); vm.cancel() } } }
            if let message = vm.message { ReviewNotice(message, isError: true) }
            Text(vm.comparisonSummary).font(.headline)
            if let comparison = vm.comparison {
                ForEach(comparison.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        ForEach(comparison.items) { item in comparisonRow(item) }
                    }.padding(DesignSystem.Spacing.medium)
                }.workspaceCard()
            } else { Spacer() }
        }.padding(DesignSystem.Spacing.large).background(DesignSystem.Colors.background)
        .onDisappear { task?.cancel(); vm.cancel() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): task = Task { await vm.importBaseline(from: url) }
            case .failure(let error): vm.finishedFileOperation(.failure(error))
            }
        }
        .fileExporter(isPresented: $isExporting, document: TextExportDocument(text: vm.exportText ?? ""),
                      contentType: .json, defaultFilename: "StorageFix Scan Snapshot.json", onCompletion: vm.finishedFileOperation)
    }
    private func comparisonRow(_ item: ScanComparison.Item) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text(item.path).font(.callout.weight(.medium)).textSelection(.enabled)
            Text("\(item.change.rawValue) · \(vm.size(item.beforeBytes)) → \(vm.size(item.afterBytes))")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            Divider()
        }
    }
}
