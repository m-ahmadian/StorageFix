import StorageFixCore
import StorageFixDesignSystem
import SwiftUI
import UniformTypeIdentifiers

struct QueueReportExportView: View {
    @ObservedObject var viewModel: ReviewQueueViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var preparation: Task<Void, Never>?
    @State private var isSaving = false
    private var contentType: UTType {
        switch viewModel.reportDocument?.format ?? .text { case .text: .plainText; case .json: .json; case .csv: .commaSeparatedText }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Export operation results").font(.title2.weight(.semibold))
            Picker("Format", selection: Binding(get: { viewModel.reportFormat }, set: { viewModel.setReportFormat($0) })) {
                ForEach(QueueReportFormat.allCases) { Text($0.rawValue).tag($0) }
            }.disabled(viewModel.isPreparingReport)
            Toggle("Include full paths and original error details", isOn: Binding(
                get: { viewModel.reportIncludesPaths }, set: { viewModel.setReportIncludesPaths($0) })).disabled(viewModel.isPreparingReport)
            Text("Paths and identifying errors are omitted by default. Review this preview before saving or sharing.")
                .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText)
            Button("Generate Preview") { preparation = Task { await viewModel.prepareReport() } }.disabled(viewModel.isPreparingReport)
            if viewModel.isPreparingReport { ProgressView("Preparing report…") }
            ScrollView { Text(viewModel.reportPreview).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            if let error = viewModel.reportError { ReviewNotice(error, isError: true) }
            HStack {
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Report…") { isSaving = true }.disabled(viewModel.reportDocument == nil || viewModel.isPreparingReport)
            }
        }.padding(DesignSystem.Spacing.large).frame(width: DesignSystem.Size.reportWidth, height: DesignSystem.Size.reportHeight)
        .background(DesignSystem.Colors.background)
        .onDisappear { preparation?.cancel(); viewModel.clearReport() }
        .fileExporter(isPresented: $isSaving, document: TextExportDocument(text: viewModel.reportDocument?.text ?? ""),
            contentType: contentType, defaultFilename: "StorageFix Queue Results.\(viewModel.reportDocument?.format.fileExtension ?? "txt")",
            onCompletion: { viewModel.finishedExport($0) })
    }
}
