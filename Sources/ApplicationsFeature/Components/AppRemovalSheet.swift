import StorageFixCore
import SwiftUI

/// Review before removing an app and its leftovers (direct edition), or only its leftovers (App Store edition).
struct AppRemovalSheet: View {
    let application: InstalledApplication
    @ObservedObject var vm: ApplicationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(vm.permitsRemoval ? "Uninstall \(application.name)?" : "Remove \(application.name) data?").font(.title2.bold())
            Text(vm.permitsRemoval
                 ? "The app (\(size(application.bytes))) and the leftovers you keep checked go to the Trash. Quit the app first."
                 : "The checked settings, caches and saved state go to the Trash. The app stays installed and starts fresh, as if new. Quit it first.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if vm.findsRelatedFiles { leftovers }
            HStack {
                Button("Cancel") { vm.cancelReview() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle, role: .destructive) { Task { await vm.moveToTrash() } }
                    .disabled(vm.isFindingRelated || (!vm.permitsRemoval && vm.selectedRelated.isEmpty))
            }
        }.padding(28).frame(width: 600)
    }

    @ViewBuilder private var leftovers: some View {
        if let error = vm.relatedError {
            Label(error, systemImage: "lock").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } else if vm.isFindingRelated {
            HStack { ProgressView().controlSize(.small); Text("Looking for leftovers…") }
        } else if vm.relatedFiles.isEmpty {
            Text("No settings, caches or support files were found for this app.").font(.callout).foregroundStyle(.secondary)
        } else {
            Text("Leftovers found: \(vm.relatedFiles.count) · selected \(size(vm.selectedRelatedBytes))").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.relatedFiles) { file in
                        Toggle(isOn: Binding(get: { vm.selectedRelated.contains(file.path) }, set: { vm.setRelated(file.path, $0) })) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name).font(.callout).lineLimit(1).truncationMode(.middle)
                                    Text(file.matchedByName ? "\(file.location) · matched by name, check before removing" : file.location)
                                        .font(.caption).foregroundStyle(file.matchedByName ? Color.orange : .secondary)
                                }
                                Spacer()
                                Text(size(file.bytes)).font(.caption).monospacedDigit()
                            }
                        }.toggleStyle(.checkbox).help(file.path)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 260)
        }
    }

    private var actionTitle: String {
        if vm.permitsRemoval { return vm.selectedRelated.isEmpty ? "Move App to Trash" : "Move App and \(vm.selectedRelated.count) Items to Trash" }
        return "Move \(vm.selectedRelated.count) Items to Trash"
    }

    private func size(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
