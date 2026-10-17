import StorageFixDesignSystem
import SwiftUI
import UniformTypeIdentifiers

struct ReviewReportView: View {
    let report: ReviewReport
    let openArea: (WorkspaceSection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text(report.heading).font(.title2.weight(.semibold))
            Text(report.explanation).font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    ForEach(report.areas) { area in areaRow(area) }
                    ReviewNotice("Folder files and duplicate copies overlap. Application bundle sizes and cache sizes are separate inventories. Review each area before deciding what to remove.")
                }
            }
            if let exportError { ReviewNotice(exportError, isError: true) }
            Text("Export includes folder paths and scan errors. Review it before sharing.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            HStack {
                Button("Export Report…", systemImage: "square.and.arrow.up") { isExporting = true }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignSystem.Spacing.large)
        .frame(width: DesignSystem.Size.reportWidth, height: DesignSystem.Size.reportHeight)
        .background(DesignSystem.Colors.background)
        .fileExporter(isPresented: $isExporting, document: ReviewReportDocument(text: report.text),
                      contentType: .plainText, defaultFilename: "StorageFix Review.txt") { result in
            switch result {
            case .success: exportError = nil
            case .failure(let error): exportError = "Could not export the report: \(error.localizedDescription)"
            }
        }
    }

    private func areaRow(_ area: ReviewAreaResult) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Label(area.section.rawValue, systemImage: area.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.headline)
                Spacer()
                Button("Open \(area.section.rawValue)") { dismiss(); openArea(area.section) }
            }
            Text(area.summary).font(.callout)
            Text(area.scope).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let error = area.error { ReviewNotice(error, isError: true) }
        }
        .textSelection(.enabled)
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
    }
}
