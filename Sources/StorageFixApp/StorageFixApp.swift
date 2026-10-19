import AppKit
import StorageFixCore
import StorageFixDesignSystem
import SwiftUI
import WorkspaceFeature

@main
struct StorageFixApp: App {
    private let folderAccess: FolderAccessSession
    @State private var showsPrivacy = false
    @StateObject private var workspace: WorkspaceViewModel
    init() {
        let script = Bundle.main.url(forResource: "storage-fix", withExtension: "sh")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Scripts/storage-fix.sh")
        let access = FolderAccessSession()
        folderAccess = access
        let remembered = access.restoreRemembered()
        _workspace = StateObject(wrappedValue: WorkspaceAssembly.make(scriptURL: script, rememberedFolders: remembered))
    }
    private var privacyText: String {
        guard let url = Bundle.main.url(forResource: "Privacy-Policy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "StorageFix processes file contents and metadata locally. It has no analytics, tracking, advertising, account, or network uploads. Preferences and recent activity stay on this Mac."
        }
        return text
    }
    var body: some Scene {
        WindowGroup {
            WorkspaceView(viewModel: workspace).environment(\.folderAccessSession, folderAccess).sheet(isPresented: $showsPrivacy) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Privacy & your files").font(.title2.bold())
                    ScrollView { Text(privacyText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    HStack { Spacer(); Button("Done") { showsPrivacy = false }.keyboardShortcut(.defaultAction) }
                }.padding(28).frame(width: 600, height: 500)
            }
        }
            .defaultSize(width: 1240, height: 860).windowResizability(.contentMinSize).windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(after: .appSettings) {
                    if DistributionMode.current == .appStore {
                        // Removes the remembered Home grant; cache cleanup asks again on next launch.
                        Button("Forget Cache Access") { folderAccess.forgetRemembered() }
                    }
                }
                CommandGroup(replacing: .help) {
                    Button("Privacy Policy") { showsPrivacy = true }
                    Button("StorageFix Help") {
                        if let guide = Bundle.main.url(forResource: "Quick-Start", withExtension: "txt") { NSWorkspace.shared.open(guide) }
                    }
                }
            }
    }
}
