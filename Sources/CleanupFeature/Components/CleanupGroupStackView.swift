import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct CleanupGroupStackView: View {
    private enum Sort: String, CaseIterable, Identifiable {
        case size = "Size", category = "Category"
        var id: String { rawValue }
    }
    @ObservedObject var viewModel: CleanupViewModel
    @State private var sort: Sort = .size
    @State private var query = ""
    @State private var hidesEmpty = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                TextField("Filter caches by name or path", text: $query).textFieldStyle(.roundedBorder)
                Toggle("Hide empty", isOn: $hidesEmpty).toggleStyle(.checkbox)
                Picker("Sort cleanup by", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 165)
            }.padding(.bottom, 4)
            if visibleGroups.isEmpty && viewModel.hasScanned {
                ContentUnavailableView("No matching caches", systemImage: "tray", description: Text("Clear the filter or show empty categories to see more."))
            }
            ForEach(visibleGroups) { group in
                CleanupGroupView(
                    group: group, categories: visibleCategories(in: group),
                    sizeDescription: viewModel.groupSizeDescription(for: group),
                    selectionState: viewModel.groupSelectionState(for: group), isLoading: viewModel.isLoading, allowsGroupSelection: query.isEmpty,
                    categorySizeDescription: viewModel.sizeDescription, isCategorySelected: viewModel.isCategorySelected,
                    toggleCategory: viewModel.setCategory, toggleGroup: { viewModel.toggleGroup(group) }
                )
            }
        }
    }
    private func visibleCategories(in group: CleanupGroup) -> [CleanupCategory] {
        viewModel.categories(in: group).filter {
            (!hidesEmpty || $0.bytesAfter > 0) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.path.localizedCaseInsensitiveContains(query))
        }
    }
    private var visibleGroups: [CleanupGroup] {
        CleanupGroup.all.filter { !visibleCategories(in: $0).isEmpty }.sorted {
            // Keep destructive optional data at the end, even when sorted by size.
            if $0.id == "advanced" || $1.id == "advanced" { return $1.id == "advanced" && $0.id != "advanced" }
            return sort == .category ? $0.title < $1.title : viewModel.groupBytes(for: $0) > viewModel.groupBytes(for: $1)
        }
    }
}
