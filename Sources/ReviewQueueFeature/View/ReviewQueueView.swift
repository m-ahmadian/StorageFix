import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct ReviewQueueView: View {
    @ObservedObject private var vm: ReviewQueueViewModel
    @State private var showsExport = false
    @State private var operation: Task<Void, Never>?
    public init(viewModel: ReviewQueueViewModel) { vm = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            FeatureHeading("Review Queue", subtitle: "Review files from across your scans in one place.") {
                Button("Export Results…") { viewModelExport() }.disabled(!vm.canExport)
                Button("Clear Queue", action: vm.clear).disabled(vm.isExecuting || vm.snapshot.items.isEmpty)
            }
            Text(vm.countDescription).font(.title3.weight(.semibold))
            Text("Sizes are logical file sizes, not guaranteed recovered space. Files move to Trash; restore them in Finder before emptying it.")
                .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
            if let message = vm.message { ReviewNotice(message, isError: true) }
            if vm.isExecuting {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(vm.progressDescription)
                    Spacer()
                    Button("Cancel Remaining") { operation?.cancel() }
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    if vm.snapshot.items.isEmpty { emptyState }
                    ForEach(vm.snapshot.items) { item in queueRow(item) }
                    runResults
                }
            }
            Button("Review \(vm.snapshot.items.count) Files for Trash", action: vm.requestConfirmation)
                .buttonStyle(PrimaryButtonStyle()).disabled(!vm.canExecute)
        }
        .padding(DesignSystem.Spacing.large).background(DesignSystem.Colors.background)
        .sheet(isPresented: $vm.showsConfirmation) { confirmation }
        .sheet(isPresented: $showsExport) { QueueReportExportView(viewModel: vm) }
    }

    private func viewModelExport() { vm.clearReport(); showsExport = true }

    private var emptyState: some View {
        ContentUnavailableView(vm.emptyTitle, systemImage: "tray", description: Text(vm.emptyDescription))
    }
    private func queueRow(_ item: ReviewQueueItem) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(item.id).font(.callout.weight(.semibold)).textSelection(.enabled)
                Spacer()
                Text(vm.size(item.file.bytes)).monospacedDigit()
            }
            Text(vm.origins(item)).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            if let blocker = vm.snapshot.blockers[item.id] { ReviewNotice(blocker, isError: true) }
            HStack {
                Button("Quick Look") { vm.preview(item.id) }.disabled(!vm.canPresent)
                Button("Show in Finder") { vm.reveal(item.id) }.disabled(!vm.canPresent)
                Spacer()
                Button("Remove from Queue") { vm.remove(item.id) }.disabled(vm.isExecuting)
            }
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }
    @ViewBuilder private var runResults: some View {
        if let run = vm.snapshot.lastRun, let summary = vm.runDescription {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Last operation · \(run.date.formatted())").font(.headline)
                Text(summary).font(.callout)
                if let freeSpace = vm.freeSpaceDescription {
                    HStack(alignment: .firstTextBaseline) {
                        Text(freeSpace).font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                        Spacer()
                        Button("Measure Again", action: vm.remeasureFreeSpace).disabled(!vm.canRemeasureFreeSpace)
                            .accessibilityHint("Reads the volume's current free space. Does not change files.")
                    }
                }
                ForEach(run.outcomes) { outcome in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                        Text("\(vm.status(outcome)) · \(outcome.path)").font(.callout).textSelection(.enabled)
                        Text(outcome.message).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    Divider()
                }
            }.padding(DesignSystem.Spacing.medium).workspaceCard()
        }
    }
    private var confirmation: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Confirm files for Trash").font(.title2.weight(.semibold))
            Text("Each file and every affected kept duplicate will be checked again. A failed preflight blocks the whole batch. Later failures are reported per file.")
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    ForEach(vm.confirmationSnapshot?.items ?? []) { item in Text(item.id).textSelection(.enabled) }
                }
            }
            HStack {
                Button("Cancel", action: vm.cancelConfirmation).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Move Reviewed Files to Trash", role: .destructive) { operation = Task { await vm.execute() } }
                    .disabled(!vm.canExecute)
            }
        }.padding(DesignSystem.Spacing.large)
            .frame(width: DesignSystem.Size.reportWidth, height: DesignSystem.Size.reportHeight)
    }
}
