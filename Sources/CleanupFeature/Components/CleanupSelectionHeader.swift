import StorageFixDesignSystem
import SwiftUI

struct CleanupSelectionHeader: View {
    let selectAllTitle: String
    let isDisabled: Bool
    let toggleSelectAll: () -> Void

    var body: some View {
        HStack {
            Text("Cleanup Categories")
                .font(.headline)
            Spacer()
            Button(selectAllTitle, action: toggleSelectAll)
                .buttonStyle(.bordered)
                .disabled(isDisabled)
        }
    }
}
