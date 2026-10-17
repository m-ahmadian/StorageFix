import StorageFixDesignSystem
import SwiftUI

struct CleanupStatusView: View {
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(DesignSystem.Colors.warning)
        }
    }
}
