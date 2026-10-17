import AppKit
import StorageFixDesignSystem
import SwiftUI
import StorageFixCore

struct SafetyView: View {
    @AppStorage("reviewedPrivacy") private var privacy = false
    @AppStorage("reviewedLoginItems") private var login = false
    @AppStorage("reviewedSoftwareUpdate") private var updates = false
    @State private var openError = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Safety check").font(.system(size: 30, weight: .semibold))
                Text("A quick guided review of your Mac’s built-in controls. Mark each step after you’ve reviewed it.").font(.callout).foregroundStyle(.secondary)
                HStack { Label("\([privacy, login, updates].filter { $0 }.count) of 3 steps reviewed", systemImage: "checklist").font(.headline); Spacer(); Button("Reset Checklist") { privacy = false; login = false; updates = false } }
                    .padding(18).background(DesignSystem.Colors.accent.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                row(title: "Privacy permissions", detail: "Check which apps can access your camera, microphone, screen and files. Search for Privacy & Security in System Settings.", icon: "hand.raised", url: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension", reviewed: $privacy)
                row(title: "Login items", detail: "Review software that opens at login or runs in the background. Search for Login Items in System Settings.", icon: "power", url: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension", reviewed: $login)
                row(title: "Software update", detail: "Check for macOS updates and review automatic update settings. Search for Software Update in System Settings.", icon: "arrow.triangle.2.circlepath", url: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension", reviewed: $updates)
                Label("This checklist records your review; it does not scan for malware or verify your security settings.", systemImage: "info.circle").foregroundStyle(.secondary)
            }.padding(32)
        }.background(DesignSystem.Colors.background).alert("Couldn’t open this setting", isPresented: $openError) {
            Button("Open System Settings") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app")) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Open System Settings and search for the setting’s name.") }
    }
    private func row(title: String, detail: String, icon: String, url: String, reviewed: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(DesignSystem.Colors.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }
            Spacer()
            Toggle("Reviewed", isOn: reviewed).toggleStyle(.checkbox)
            Button("Open Settings", systemImage: "arrow.up.forward") {
                let target = DistributionMode.current == .appStore
                    ? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences")
                    : URL(string: url)
                if let target, NSWorkspace.shared.open(target) {} else { openError = true }
            }
        }.padding(20).workspaceCard()
    }
}
