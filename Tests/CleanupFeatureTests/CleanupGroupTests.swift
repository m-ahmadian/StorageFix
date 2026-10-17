import CleanupFeature
import StorageFixCore
import Testing

@MainActor
struct CleanupGroupTests {
    @Test func `Given cleanup groups, when mapping categories, then every category appears exactly once`() {
        let mappedIDs = CleanupGroup.all.flatMap(\.categoryIDs)
        let standardGroupsExpanded = CleanupGroup.all
            .dropLast()
            .allSatisfy { $0.isExpandedByDefault }

        #expect(mappedIDs.count == Set(mappedIDs).count)
        #expect(Set(mappedIDs) == expectedCategoryIDs)
        #expect(CleanupGroup.all.last?.id == "advanced")
        #expect(CleanupGroup.all.last?.isExpandedByDefault == false)
        #expect(standardGroupsExpanded)
    }

    @Test func `Given a scan report, when totaling a group, then current category sizes are used`() async throws {
        let viewModel = makeViewModel()
        await viewModel.scan()
        let group = try #require(findGroup(id: "developer-tools"))

        #expect(viewModel.groupBytes(for: group) == 350)
        #expect(viewModel.groupSizeDescription(for: group) == "350 bytes")
    }

    @Test func `Given empty group members, when selecting a group, then only nonempty members are selected`() async throws {
        let viewModel = makeViewModel()
        await viewModel.scan()
        clearSelection(in: viewModel)
        let group = try #require(findGroup(id: "developer-tools"))

        viewModel.toggleGroup(group)

        #expect(viewModel.selectedCategoryIDs == ["xcode-derived-data", "xcode-doc-cache"])
        #expect(viewModel.groupSelectionState(for: group) == .all)
    }

    @Test func `Given a selected group, when toggling it, then its members are deselected`() async throws {
        let viewModel = makeViewModel()
        await viewModel.scan()
        let group = try #require(findGroup(id: "developer-tools"))
        viewModel.toggleGroup(group)

        #expect(viewModel.groupSelectionState(for: group) == .none)
        #expect(viewModel.selectedCategoryIDs.contains("simulator-contents"))
    }

    @Test func `Given group members, when selecting individual categories, then group state updates`() async throws {
        let viewModel = makeViewModel()
        await viewModel.scan()
        clearSelection(in: viewModel)
        let group = try #require(findGroup(id: "developer-tools"))

        viewModel.setCategory("xcode-derived-data", isSelected: true)
        #expect(viewModel.groupSelectionState(for: group) == .some)

        viewModel.setCategory("xcode-doc-cache", isSelected: true)
        #expect(viewModel.groupSelectionState(for: group) == .all)
    }

    @Test func `Given several groups, when selecting all, then nonempty categories across groups are selected`() async {
        let viewModel = makeViewModel()
        await viewModel.scan()
        clearSelection(in: viewModel)

        viewModel.toggleSelectAll()

        #expect(viewModel.selectedCategoryIDs == selectableFixtureIDs)
        #expect(viewModel.areAllCategoriesSelected)
    }

    private func makeViewModel() -> CleanupViewModel {
        CleanupViewModel(service: GroupMockCleanupService())
    }

    private func findGroup(id: String) -> CleanupGroup? {
        CleanupGroup.all.first { $0.id == id }
    }

    private func clearSelection(in viewModel: CleanupViewModel) {
        for id in viewModel.selectedCategoryIDs {
            viewModel.setCategory(id, isSelected: false)
        }
    }
}

private struct GroupMockCleanupService: CleanupServiceProtocol {
    func scan() async throws -> CleanupReport { .groupFixture }

    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { .groupFixture }
}

private let expectedCategoryIDs: Set<String> = [
    "xcode-derived-data", "xcodebuildmcp-cache", "xcode-doc-cache",
    "swiftpm-cache", "npm-cache", "node-gyp-cache",
    "google-cache", "claude-cache", "adobe-cache", "codex-runtime-cache", "user-cache-files",
    "app-logs", "simulator-contents", "ios-device-support"
]

private let selectableFixtureIDs: Set<String> = [
    "xcode-derived-data", "xcode-doc-cache", "simulator-contents"
]

private extension CleanupReport {
    static let groupFixture = CleanupReport(
        mode: "scan",
        freeBytesBefore: 2_000,
        freeBytesAfter: 2_000,
        freeBytesReclaimed: 0,
        categories: [
            fixtureCategory(id: "xcode-derived-data", bytes: 100),
            fixtureCategory(id: "xcodebuildmcp-cache", bytes: 0),
            fixtureCategory(id: "xcode-doc-cache", bytes: 250),
            fixtureCategory(id: "simulator-contents", bytes: 400)
        ]
    )

    static func fixtureCategory(id: String, bytes: Int64) -> CleanupCategory {
        CleanupCategory(
            id: id,
            name: id,
            path: "/\(id)",
            safeDefault: true,
            warning: "",
            bytesBefore: bytes,
            bytesAfter: bytes
        )
    }
}
