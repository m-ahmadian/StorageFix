import StorageFixCore
import Charts
import StorageFixDesignSystem
import SwiftUI

public struct QuickReviewView: View {
    @Environment(\.folderAccessSession) private var folderAccess

    @ObservedObject private var vm: WorkspaceViewModel
    private let select: (WorkspaceSection) -> Void
    @State private var showsReport = false
    @State private var showsAllActivity = false

    public init(viewModel: WorkspaceViewModel, select: @escaping (WorkspaceSection) -> Void) {
        vm = viewModel
        self.select = select
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                heading
                introduction
                cleanNowCard
                ReviewJourneyView(journey: vm.journey, guidance: vm.journeyGuidance, actionTitle: vm.journeyActionTitle, action: select,
                    secondaryTitle: vm.latestReport == nil ? nil : "View Report…", secondaryAction: { showsReport = true })
                if vm.isReviewing { progress }
                reviewOutcome
                HStack {
                    Text(vm.lastReviewDate == nil ? "Make a little room" : "Your review, in focus").font(.title3.weight(.semibold))
                    Spacer()
                    Text("Review first. Act second.").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                reviewCards
                HStack(spacing: DesignSystem.Spacing.medium) {
                    shortcut("Explore storage", subtitle: "Follow the space", symbol: "chart.pie", section: .map)
                    shortcut("Safety checklist", subtitle: "Review macOS settings", symbol: "checkmark.shield", section: .safety)
                }
                if !vm.activity.isEmpty { activity }
                Text("Scans never remove files. Cache cleanup and Trash actions always ask you to review and confirm.")
                    .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            }.padding(DesignSystem.Spacing.xLarge)
        }
        .background(DesignSystem.Colors.background).task { vm.refreshDisk() }
        .sheet(isPresented: $showsReport) {
            if let report = vm.latestReport { ReviewReportView(report: report, openArea: select) }
        }
    }

    private var heading: some View {
        HStack {
            Label("YOUR WORKSPACE", systemImage: "sparkles").font(.caption.weight(.semibold))
            Spacer()
            if let date = vm.lastReviewDate {
                Text("Reviewed \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption)
            }
        }.foregroundStyle(DesignSystem.Colors.secondaryText)
    }

    private var introduction: some View {
        HStack(spacing: DesignSystem.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Text("Know what’s taking space.").font(.largeTitle.weight(.semibold))
                Text(vm.reviewsApplications ? "Review the chosen folder, installed apps and rebuildable caches. You choose what happens next." : "Scan caches, developer junk, old installers and leftovers of deleted apps, plus your Downloads. You choose what happens next.")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Compare file contents for duplicates (optional)", isOn: Binding(
                    get: { vm.includesDuplicateComparison }, set: { vm.setDuplicateComparison($0) }))
                    .toggleStyle(.checkbox).disabled(vm.isBusy)
                HStack(spacing: DesignSystem.Spacing.small) {
                    if vm.needsHomeAllow {
                        Button("Scan My Mac", systemImage: "sparkles") { allowAndReview() }
                            .buttonStyle(PrimaryButtonStyle()).disabled(vm.isBusy)
                    } else {
                        Button(vm.lastReviewDate == nil ? "Start Review" : "Review Again", systemImage: "sparkles") {
                            vm.startReview()
                        }.buttonStyle(PrimaryButtonStyle()).disabled(!vm.canReview)
                    }
                    Button("Choose Folder…", systemImage: "folder") {
                        if let folder = FolderPicker.choose(access: folderAccess) { vm.chooseReviewFolder(folder) }
                    }.disabled(vm.isBusy)
                }
                Text(vm.needsHomeAllow ? "macOS asks once: click Allow and StorageFix scans caches, old installers and Downloads. Nothing is removed until you confirm."
                     : vm.files.needsFolder ? "Choose a folder to begin; access stays under your control." : "Folder review: \(vm.files.scope.path)")
                    .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Spacer(minLength: DesignSystem.Spacing.none)
            diskSummary.frame(width: DesignSystem.Size.reviewDiskWidth)
        }.padding(DesignSystem.Spacing.large).workspaceCard()
    }

    /// The panel opens on Home, so a single Allow click grants it; the review then starts by itself.
    private func allowAndReview() {
        guard let folder = FolderPicker.choose(access: folderAccess, startingAt: vm.cleanup.requiredFolder,
            message: "Click Allow to let StorageFix scan your Mac for junk. Nothing is removed until you confirm.", prompt: "Allow") else { return }
        Task { if await vm.allowHomeAndReview(folder) { folderAccess?.remember(folder) } }
    }

    private var progress: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text(vm.reviewStep).font(.headline)
                ProgressView(value: Double(vm.completedSteps), total: Double(vm.reviewStageCount))
                    .frame(width: DesignSystem.Size.reviewProgressWidth)
                    .accessibilityLabel("Review progress")
                    .accessibilityValue("\(vm.completedSteps) of \(vm.reviewStageCount) scans completed")
            }
            Spacer()
            Text("\(vm.completedSteps) of \(vm.reviewStageCount) completed").font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Button("Cancel") { vm.stopReview() }
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }

    /// Problems, cancellations and queue results stay visible; a clean review is summarised by the journey card.
    @ViewBuilder private var reviewOutcome: some View {
        if let message = vm.reviewMessage, vm.latestReport == nil || vm.latestReport?.needsAttention == true {
            ReviewNotice(message, isError: vm.latestReport?.needsAttention == true)
        }
    }

    private var reviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.medium) {
            reviewCard(title: "Cleanup", detail: "Rebuildable caches & logs", value: cleanupCardValue, symbol: "leaf", color: DesignSystem.Colors.accent, error: vm.cleanup.needsAccess ? nil : vm.cleanup.errorMessage, section: .cleanup)
            reviewCard(title: "Duplicates", detail: vm.duplicates.scopeDescription, value: vm.duplicates.hasScanned ? "\(vm.duplicates.duplicateCount) extra \(vm.duplicates.duplicateCount == 1 ? "copy" : "copies")" : "Keep your favorites", symbol: "doc.on.doc", color: DesignSystem.Colors.lilac, error: vm.duplicates.errorMessage, section: .duplicates)
            reviewCard(title: "Large & old files", detail: "Filter by size, type & modified date", value: vm.fileInventoryDescription, symbol: "folder", color: DesignSystem.Colors.files, error: vm.files.errorMessage, section: .files)
            if vm.reviewsApplications {
                reviewCard(title: "Applications", detail: "App bundles, sorted by disk usage", value: vm.apps.hasScanned ? "\(vm.apps.applications.count) installed \(vm.apps.applications.count == 1 ? "app" : "apps")" : "A simpler collection", symbol: "square.stack.3d.up", color: DesignSystem.Colors.amber, error: vm.apps.errorMessage, section: .apps)
            } else {
                reviewCard(title: "Storage map", detail: "Explore the chosen folder", value: vm.map.hasScanned ? "\(vm.map.items.count) items to explore" : "Follow the space", symbol: "chart.pie", color: DesignSystem.Colors.amber, error: vm.map.errorMessage, section: .map)
            }
        }
    }

    private var cleanupCardValue: String {
        if vm.cleanup.needsAccess { return "Allow cache cleanup" }
        return vm.cleanup.hasScanned ? "\(vm.cleanup.cleanableSizeDescription) to clean" : "Ready to scan"
    }

    /// One click from a finished review to the cleanup confirmation sheet.
    @ViewBuilder private var cleanNowCard: some View {
        if vm.cleanup.hasScanned, vm.cleanup.selectedBytes > 0, !vm.cleanup.isLoading, vm.reviewQueue?.isExecuting != true {
            HStack(spacing: DesignSystem.Spacing.medium) {
                IconBadge("leaf", color: DesignSystem.Colors.accent)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                    Text("\(vm.cleanup.selectedSizeDescription) of caches ready to clean").font(.title3.weight(.semibold))
                    Text("Recommended categories are preselected. You see every folder and warning before anything is deleted.")
                        .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Button("Review & Clean", systemImage: "sparkles") { vm.reviewAndClean() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(DesignSystem.Spacing.large).workspaceCard()
            .accessibilityElement(children: .combine)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Recent activity").font(.headline)
                Spacer()
                Button("Clear History") { vm.clearActivity() }.font(.caption)
            }
            ForEach(vm.visibleActivity(expanded: showsAllActivity)) { item in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "clock").foregroundStyle(DesignSystem.Colors.secondaryText).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                        Text(item.title).font(.callout.weight(.medium))
                        Text(item.detail).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
            if vm.hasMoreActivity {
                Button(showsAllActivity ? "Show Less" : "Show All Activity (\(vm.activity.count))") { showsAllActivity.toggle() }
                    .font(.caption)
            }
        }.padding(DesignSystem.Spacing.large).workspaceCard()
    }

    private var diskSummary: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            if let capacity = vm.capacityBytes, let free = vm.availableBytes, capacity > 0 {
                Chart {
                    SectorMark(angle: .value("Used", max(0, capacity - free)), innerRadius: .ratio(DesignSystem.Chart.ringRatio), angularInset: DesignSystem.Chart.angularInset)
                        .foregroundStyle(pressureColor)
                    SectorMark(angle: .value("Available", min(capacity, free)), innerRadius: .ratio(DesignSystem.Chart.ringRatio), angularInset: DesignSystem.Chart.angularInset)
                        .foregroundStyle(DesignSystem.Colors.groupHeader)
                }.frame(width: DesignSystem.Size.reviewChart, height: DesignSystem.Size.reviewChart)
                    .chartBackground { _ in
                        VStack(spacing: DesignSystem.Spacing.xSmall) {
                            Text(vm.usedPercentage).font(.title.weight(.semibold))
                            Text("used").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .accessibilityLabel("Disk space")
                    .accessibilityValue("\(vm.usedPercentage) used. \(vm.size(free)) available of \(vm.size(capacity)).\(vm.storagePressure.status.map { " \($0)." } ?? "")")
                Text("\(vm.size(free)) available").font(.callout.weight(.semibold))
                Text("of \(vm.size(capacity))").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                if let status = vm.storagePressure.status {
                    Label(status, systemImage: "exclamationmark.triangle.fill").font(.caption.weight(.semibold))
                        .foregroundStyle(pressureColor).accessibilityHidden(true)
                }
            } else {
                IconBadge("internaldrive")
                Text("Disk space unavailable").font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
    }

    private var pressureColor: Color {
        switch vm.storagePressure {
        case .critical: DesignSystem.Colors.critical
        case .tight: DesignSystem.Colors.warning
        case .comfortable, .unknown: DesignSystem.Colors.accent
        }
    }

    private func reviewCard(title: String, detail: String, value: String, symbol: String, color: Color, error: String?, section: WorkspaceSection) -> some View {
        Button { select(section) } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                HStack {
                    IconBadge(symbol, color: color)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
                }
                Text(error == nil ? value : "Needs attention").font(.title2.weight(.semibold))
                    .foregroundStyle(error == nil ? Color.primary : DesignSystem.Colors.warning)
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                        Text(title).font(.headline)
                        Text(detail).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText).lineLimit(1).help(detail)
                    }
                    Spacer()
                    Text("Review").font(.caption.weight(.semibold))
                }
            }.padding(DesignSystem.Spacing.large).frame(maxWidth: .infinity, alignment: .leading).workspaceCard()
        }.buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Open \(title) to review details")
    }

    private func shortcut(_ title: String, subtitle: String, symbol: String, section: WorkspaceSection) -> some View {
        Button { select(section) } label: {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: symbol).font(.title3).foregroundStyle(DesignSystem.Colors.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                    Text(title).font(.callout.weight(.medium))
                    Text(subtitle).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
            }.padding(DesignSystem.Spacing.medium).workspaceCard()
        }.buttonStyle(.plain)
    }
}
