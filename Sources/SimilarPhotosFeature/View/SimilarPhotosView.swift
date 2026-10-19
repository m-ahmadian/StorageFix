import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

public struct SimilarPhotosView: View {
    @ObservedObject private var viewModel: SimilarPhotosViewModel
    @Environment(\.folderAccessSession) private var folderAccess
    public init(viewModel: SimilarPhotosViewModel) { self.viewModel = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header
            if let progress = viewModel.progress { progressRow(progress) }
            if let message = viewModel.errorMessage { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.callout) }
            if let message = viewModel.resultMessage { Label(message, systemImage: "checkmark.circle").font(.callout) }
            content
            if !viewModel.groups.isEmpty { footer }
        }
        .padding(DesignSystem.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $viewModel.showsConfirmation) { confirmation }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text("Similar Photos").font(.largeTitle.weight(.semibold))
                Text("Finds burst shots, edits and resized copies on this Mac. Pick the ones you don't need; they go to the Trash.")
                    .font(.callout).foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(viewModel.folder.map { "Folder: \($0.path)" } ?? "Choose a folder of photos to begin.")
                    .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryText).textSelection(.enabled)
            }
            Spacer()
            Button("Choose Folder…", systemImage: "folder") {
                if let folder = FolderPicker.choose(access: folderAccess) { viewModel.chooseFolder(folder) }
            }.disabled(viewModel.isLoading)
            if viewModel.isLoading && viewModel.progress != nil {
                Button("Cancel Scan") { viewModel.cancelScan() }
            } else {
                Button(viewModel.hasScanned ? "Scan Again" : "Find Similar Photos", systemImage: "photo.on.rectangle.angled") {
                    viewModel.startScan()
                }.buttonStyle(PrimaryButtonStyle()).disabled(viewModel.needsFolder || viewModel.isLoading)
            }
        }
    }

    private func progressRow(_ progress: SimilarPhotoProgress) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
            Text(progress.total == 0 ? "Looking for photos…" : "Comparing photos… \(progress.analyzed) of \(progress.total)").font(.callout)
            ShareBar(value: Int64(progress.analyzed), total: Int64(progress.total), color: DesignSystem.Colors.accent)
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.hasScanned && viewModel.analyzedCount == 0 {
            ContentUnavailableView("No photos in this folder", systemImage: "photo.on.rectangle",
                description: Text("Pictures kept inside the Photos app are not scanned. Choose a folder with image files, such as Desktop, Downloads or a camera import folder."))
                .frame(maxHeight: .infinity)
        } else if viewModel.hasScanned && viewModel.groups.isEmpty {
            ContentUnavailableView("No similar photos", systemImage: "photo.on.rectangle",
                description: Text("Compared \(viewModel.analyzedCount) photos. Nothing looks alike."))
                .frame(maxHeight: .infinity)
        } else if !viewModel.hasScanned && !viewModel.isLoading {
            ContentUnavailableView("Find look-alike photos", systemImage: "photo.on.rectangle.angled",
                description: Text("Photos are compared on this Mac with Apple's image analysis. Your Photos library is not touched."))
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.medium) {
                    if viewModel.wasLimited {
                        Label("This folder has many photos; the newest \(viewModel.analyzedCount) were compared. Choose a smaller folder to compare older ones.", systemImage: "info.circle")
                            .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(viewModel.groups) { group in
                        SimilarPhotoGroupCard(group: group, viewModel: viewModel) { path in
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.selectedPaths.count) selected · \(viewModel.size(viewModel.selectedBytes))").font(.headline)
                Text("\(viewModel.groups.count) groups · up to \(viewModel.size(viewModel.extraBytes)) in extras").font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            Button("Select All but Best") { viewModel.selectAllButBest() }.disabled(viewModel.isLoading)
            Button("Clear") { viewModel.clearSelection() }.disabled(viewModel.selectedPaths.isEmpty || viewModel.isLoading)
            Button("Move to Trash…") { viewModel.requestTrash() }
                .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.selectedPaths.isEmpty || viewModel.isLoading)
        }
        .padding(DesignSystem.Spacing.medium).workspaceCard()
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move \(viewModel.selectedPaths.count) photos to the Trash?").font(.title2.bold())
            Text("Every group keeps at least one photo. You can restore these from the Trash until you empty it.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.selectedPhotos) { Text($0.path).font(.caption.monospaced()).textSelection(.enabled) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 260)
            HStack {
                Button("Cancel") { viewModel.showsConfirmation = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Move \(viewModel.size(viewModel.selectedBytes)) to Trash", role: .destructive) { Task { await viewModel.confirmTrash() } }
            }
        }.padding(28).frame(width: 600)
    }
}
