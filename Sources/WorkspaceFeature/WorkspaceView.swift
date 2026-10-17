import ApplicationsFeature
import AppKit
import CleanupFeature
import DuplicateFeature
import LargeFilesFeature
import ReviewQueueFeature
import ScanComparisonFeature
import StorageFixDesignSystem
import StorageMapFeature
import SwiftUI

public struct WorkspaceView: View {
    @ObservedObject private var vm: WorkspaceViewModel
    public init(viewModel: WorkspaceViewModel) { vm = viewModel }
    public var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 220)
            Group {
                switch vm.selectedSection {
                case .comparison: if let comparison = vm.scanComparison { ScanComparisonView(viewModel: comparison) }
                case .queue: if let queue = vm.reviewQueue { ReviewQueueView(viewModel: queue) }
                case .overview: QuickReviewView(viewModel: vm, select: vm.select)
                case .cleanup: if vm.supportsCleanup { CleanupView(viewModel: vm.cleanup) }
                case .map: StorageMapView(viewModel: vm.map)
                case .duplicates: DuplicateView(viewModel: vm.duplicates)
                case .files: LargeFilesView(viewModel: vm.files)
                case .apps: ApplicationsView(viewModel: vm.apps)
                case .safety: SafetyView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(DesignSystem.Colors.background).tint(DesignSystem.Colors.accent)
            .frame(minWidth: 1080, minHeight: 740)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(spacing: 12) {
                Image(systemName: DesignSystem.Brand.symbol).font(.title2).foregroundStyle(DesignSystem.Brand.foreground)
                    .frame(width: DesignSystem.Brand.sidebarSize, height: DesignSystem.Brand.sidebarSize).background(DesignSystem.Colors.accent).clipShape(RoundedRectangle(cornerRadius: DesignSystem.Brand.sidebarRadius))
                VStack(alignment: .leading, spacing: 3) { Text("StorageFix").font(.system(size: 17, weight: .semibold)); Text("Room to breathe").font(.caption).foregroundStyle(.white.opacity(0.55)) }
            }.padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 28)
            heading("WORKSPACE")
            navigation(.overview, key: "1")
            if vm.reviewQueue != nil { navigation(.queue, key: "8") }
            if vm.scanComparison != nil { navigation(.comparison, key: "9") }
            heading("STORAGE").padding(.top, 20)
            if vm.supportsCleanup { navigation(.cleanup, key: "2") }; navigation(.map, key: "3"); navigation(.duplicates, key: "4"); navigation(.files, key: "5")
            heading("MAC CARE").padding(.top, 20)
            navigation(.apps, key: "6"); navigation(.safety, key: "7")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Local by design", systemImage: "lock").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                Text("Your files. Your decisions.").font(.caption).foregroundStyle(.white.opacity(0.65))
                Text("VERSION 3.1").font(.system(size: 10, weight: .medium)).tracking(1.3).foregroundStyle(.white.opacity(0.55)).padding(.top, 10)
            }.padding(22)
        }.foregroundStyle(.white).background(DesignSystem.Colors.sidebar)
    }
    private func heading(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 24).padding(.bottom, 4)
    }
    private func navigation(_ item: WorkspaceSection, key: KeyEquivalent) -> some View {
        Button { vm.select(item) } label: {
            HStack(spacing: 12) { Image(systemName: item.symbol).frame(width: 20).accessibilityHidden(true); Text(vm.navigationTitle(item)).font(.system(size: 13, weight: vm.selectedSection == item ? .semibold : .regular)); Spacer() }
                .foregroundStyle(vm.selectedSection == item ? Color.white : .white.opacity(0.65))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(vm.selectedSection == item ? Color.white.opacity(0.10) : .clear).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).padding(.horizontal, 12).keyboardShortcut(key, modifiers: .command)
            .disabled(vm.isReviewing || vm.reviewQueue?.isExecuting == true).accessibilityValue(vm.selectedSection == item ? "Current section" : "")
    }
}
