import StorageFixCore
import StorageFixDesignSystem
import SwiftUI

struct CleanupGroupView: View {
    let group: CleanupGroup
    let categories: [CleanupCategory]
    let sizeDescription: String
    let selectionState: CleanupGroupSelectionState
    let isLoading: Bool
    let allowsGroupSelection: Bool
    let categorySizeDescription: (CleanupCategory) -> String
    let isCategorySelected: (String) -> Bool
    let toggleCategory: (String, Bool) -> Void
    let toggleGroup: () -> Void

    @State private var isExpanded: Bool

    init(
        group: CleanupGroup,
        categories: [CleanupCategory],
        sizeDescription: String,
        selectionState: CleanupGroupSelectionState,
        isLoading: Bool,
        allowsGroupSelection: Bool = true,
        categorySizeDescription: @escaping (CleanupCategory) -> String,
        isCategorySelected: @escaping (String) -> Bool,
        toggleCategory: @escaping (String, Bool) -> Void,
        toggleGroup: @escaping () -> Void
    ) {
        self.group = group
        self.categories = categories
        self.sizeDescription = sizeDescription
        self.selectionState = selectionState
        self.isLoading = isLoading
        self.allowsGroupSelection = allowsGroupSelection
        self.categorySizeDescription = categorySizeDescription
        self.isCategorySelected = isCategorySelected
        self.toggleCategory = toggleCategory
        self.toggleGroup = toggleGroup
        _isExpanded = State(initialValue: group.isExpandedByDefault)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            header
            if isExpanded {
                ForEach(categories) { category in
                    Divider()
                        .padding(.leading, DesignSystem.Spacing.xLarge)
                    CleanupCategoryRow(
                        category: category,
                        sizeDescription: categorySizeDescription(category),
                        isSelected: selectionBinding(for: category.id)
                    ).disabled(isLoading)
                }
            }
        }
        .background(DesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Size.border)
        }
    }

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Button(
                isExpanded ? "Collapse \(group.title)" : "Expand \(group.title)",
                systemImage: disclosureImageName,
                action: toggleExpansion
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            Button(groupSelectionLabel, systemImage: selectionImageName, action: toggleGroup)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .disabled(isLoading || !allowsGroupSelection || hasSelectableCategories == false)
            Image(systemName: groupSymbolName)
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.Size.rowIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text(group.title)
                    .font(.headline)
                Text("\(categories.count) items")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            Text(sizeDescription)
                .font(.headline)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(DesignSystem.Colors.groupHeader)
    }

    private var disclosureImageName: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var selectionImageName: String {
        switch selectionState {
        case .none: "square"
        case .some: "minus.square.fill"
        case .all: "checkmark.square.fill"
        }
    }

    private var groupSelectionLabel: String {
        "\(selectionState == .all ? "Deselect" : "Select") \(group.title)"
    }

    private var groupSymbolName: String {
        switch group.id {
        case "developer-tools": "hammer"
        case "package-caches": "shippingbox"
        case "application-caches": "square.stack.3d.up"
        case "logs": "doc.text"
        default: "gearshape"
        }
    }

    private var hasSelectableCategories: Bool {
        categories.contains { $0.bytesAfter > 0 }
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { isCategorySelected(id) },
            set: { toggleCategory(id, $0) }
        )
    }

    private func toggleExpansion() {
        isExpanded.toggle()
    }
}
