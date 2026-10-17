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
    @State private var reviewTask: Task<Void, Never>?

    public init(viewModel: WorkspaceViewModel, select: @escaping (WorkspaceSection) -> Void) {
        vm = viewModel
        self.select = select
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                heading
                introduction
                ReviewJourneyView(journey: vm.journey, guidance: vm.journeyGuidance, actionTitle: vm.journeyActionTitle, action: select)
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
                Text(vm.supportsCleanup ? "Scans never remove files. Cleanup and Trash actions always ask you to review or confirm." : "Scans never remove files. Selected files move to Trash only after your review.")
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
                Text(vm.supportsCleanup ? "Review the chosen folder, installed apps and supported caches. You choose what happens next." : "Review a folder you choose. Find duplicates and explore your files. You choose what happens next.")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Compare file contents for duplicates (optional)", isOn: Binding(
                    get: { vm.includesDuplicateComparison }, set: { vm.setDuplicateComparison($0) }))
                    .toggleStyle(.checkbox).disabled(vm.isBusy)
                HStack(spacing: DesignSystem.Spacing.small) {
                    Button(vm.lastReviewDate == nil ? (vm.supportsCleanup ? "Start Review" : "Review Folder") : "Review Again", systemImage: "sparkles") {
                        reviewTask = Task { await vm.review() }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!vm.canReview)
                    Button("Choose Folder…", systemImage: "folder") {
                        if let folder = FolderPicker.choose(access: folderAccess) { vm.chooseReviewFolder(folder) }
                    }.disabled(vm.isBusy)
                }
                Text(vm.files.needsFolder ? "Choose a folder to begin; access stays under your control." : "Folder review: \(vm.files.scope.path)")
                    .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Spacer(minLength: DesignSystem.Spacing.none)
            diskSummary.frame(width: DesignSystem.Size.reviewDiskWidth)
        }.padding(DesignSystem.Spacing.large).workspaceCard()
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
            Button("Cancel") { reviewTask?.cancel() }
        }.padding(DesignSystem.Spacing.medium).workspaceCard()
    }

    @ViewBuilder private var reviewOutcome: some View {
        if let message = vm.reviewMessage {
            HStack(spacing: DesignSystem.Spacing.medium) {
                ReviewNotice(message, isError: vm.latestReport?.needsAttention == true)
                if vm.latestReport != nil {
                    Button("View Report…", systemImage: "doc.text") { showsReport = true }
                }
            }
        }
    }

    private var reviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.medium) {
            if vm.supportsCleanup {
                reviewCard(title: "Cleanup", detail: "Rebuildable caches & optional data", value: vm.cleanup.hasScanned ? vm.cleanup.cleanableSizeDescription : "Ready to scan", symbol: "leaf", color: DesignSystem.Colors.accent, error: vm.cleanup.errorMessage, section: .cleanup)
            } else {
                reviewCard(title: "Storage map", detail: "Explore the chosen folder", value: vm.map.hasScanned ? "\(vm.map.items.count) items to explore" : "Follow the space", symbol: "chart.pie", color: DesignSystem.Colors.accent, error: vm.map.errorMessage, section: .map)
            }
            reviewCard(title: "Duplicates", detail: vm.duplicates.scopeDescription, value: vm.duplicates.hasScanned ? "\(vm.duplicates.duplicateCount) extra \(vm.duplicates.duplicateCount == 1 ? "copy" : "copies")" : "Keep your favorites", symbol: "doc.on.doc", color: DesignSystem.Colors.lilac, error: vm.duplicates.errorMessage, section: .duplicates)
            reviewCard(title: "Large & old files", detail: "Filter by size, type & modified date", value: vm.fileInventoryDescription, symbol: "folder", color: DesignSystem.Colors.files, error: vm.files.errorMessage, section: .files)
            reviewCard(title: "Applications", detail: vm.apps.permitsRemoval ? "App bundles, sorted by disk usage" : "Read-only inventory of a chosen folder", value: vm.apps.hasScanned ? "\(vm.apps.applications.count) installed \(vm.apps.applications.count == 1 ? "app" : "apps")" : (vm.apps.needsFolder ? "Choose an apps folder" : "A simpler collection"), symbol: "square.stack.3d.up", color: DesignSystem.Colors.amber, error: vm.apps.errorMessage, section: .apps)
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
        }.buttonStyle(.plain).disabled(vm.isReviewing)
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
        }.buttonStyle(.plain).disabled(vm.isReviewing)
    }
}
