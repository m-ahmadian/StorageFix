import StorageFixDesignSystem
import SwiftUI

public struct CleanupView: View {
    @ObservedObject private var viewModel: CleanupViewModel
    @State private var scanTask: Task<Void, Never>?
    private let scansOnAppear: Bool
    private let isListScrollable: Bool

    public init(viewModel: CleanupViewModel) {
        self.viewModel = viewModel
        scansOnAppear = true
        isListScrollable = true
    }

    init(
        viewModel: CleanupViewModel,
        scansOnAppear: Bool,
        isListScrollable: Bool
    ) {
        self.viewModel = viewModel
        self.scansOnAppear = scansOnAppear
        self.isListScrollable = isListScrollable
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            CleanupHeaderView()
            if viewModel.needsAccess {
                CleanupAccessCard(viewModel: viewModel)
                CleanupStatusView(errorMessage: viewModel.errorMessage)
                Spacer()
            } else {
            StorageSummaryView(
                availableBefore: viewModel.freeSpaceBeforeDescription,
                availableAfter: viewModel.freeSpaceAfterDescription,
                reclaimed: viewModel.reclaimedSpaceDescription,
                cleanable: viewModel.cleanableSizeDescription,
                selected: viewModel.selectedSizeDescription,
                remainingCleanable: viewModel.remainingCleanableSizeDescription,
                hasRemainingCleanable: viewModel.hasRemainingCleanableSpace,
                successMessage: viewModel.resultMessage,
                hasCleanupSummary: viewModel.hasCleanupSummary
            )
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(viewModel.operationDescription).foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.isCleaning { Button("Cancel Scan") { scanTask?.cancel() } }
                }
            }
            CleanupSelectionHeader(
                selectAllTitle: viewModel.selectAllButtonTitle,
                isDisabled: viewModel.isLoading || viewModel.hasSelectableCategories == false,
                toggleSelectAll: { viewModel.toggleSelectAll() }
            )
            CleanupGroupListView(
                viewModel: viewModel,
                isScrollable: isListScrollable
            )
            CleanupStatusView(errorMessage: viewModel.errorMessage)
            CleanupActionsView(
                selectedSize: viewModel.selectedSizeDescription,
                isLoading: viewModel.isLoading,
                canClean: viewModel.selectedCategoryIDs.isEmpty == false,
                rescan: rescan,
                clean: { viewModel.requestCleanup() }
            )
            }
        }
        .padding(DesignSystem.Spacing.large)
        .frame(
            minWidth: DesignSystem.Size.minimumWindowWidth,
            minHeight: DesignSystem.Size.minimumWindowHeight
        )
        .background(DesignSystem.Colors.background)
        .task {
            guard scansOnAppear, !viewModel.hasScanned, !viewModel.needsAccess else { return }
            rescan()
            await scanTask?.value
        }
        .sheet(isPresented: $viewModel.showsConfirmation) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Review cache cleanup").font(.title2.bold())
                Text(viewModel.confirmationSummary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.categories.filter { viewModel.selectedCategoryIDs.contains($0.id) }) { category in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(category.name).font(.headline)
                                Text(category.path).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                if !category.warning.isEmpty { Text(category.warning).font(.caption).foregroundStyle(.orange) .fixedSize(horizontal: false, vertical: true) }
                                if !category.items.isEmpty {
                                    Text(category.items.joined(separator: "\n")).font(.caption.monospaced()).textSelection(.enabled)
                                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Divider()
                        }
                    }
                }.frame(maxHeight: 320)
                HStack {
                    Button("Cancel") { viewModel.showsConfirmation = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(viewModel.confirmationButtonTitle, role: .destructive) { Task { await viewModel.confirmCleanup() } }
                }
            }.padding(28).frame(width: 640)
        }
        .onDisappear { if !viewModel.isCleaning { scanTask?.cancel() } }
    }

    private func rescan() {
        scanTask = Task { await viewModel.scan() }
    }
}
