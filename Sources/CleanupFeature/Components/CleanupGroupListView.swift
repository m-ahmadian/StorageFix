import StorageFixDesignSystem
import SwiftUI

struct CleanupGroupListView: View {
    @ObservedObject var viewModel: CleanupViewModel
    let isScrollable: Bool

    var body: some View {
        if isScrollable {
            ScrollView {
                CleanupGroupStackView(viewModel: viewModel)
            }
        } else {
            CleanupGroupStackView(viewModel: viewModel)
        }
    }
}
