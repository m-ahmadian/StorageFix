import CleanupFeature
import StorageFixCore
import Testing

@MainActor
struct CleanupViewModelTests {
    @Test func `Given a scan report, when scanning, then only safe nonempty defaults are selected`() async {
        let service = MockCleanupService(scanResult: .fixture)
        let viewModel = CleanupViewModel(service: service)

        await viewModel.scan()

        #expect(viewModel.categories.count == 2)
        #expect(viewModel.selectedCategoryIDs == ["xcode-derived-data"])
        #expect(viewModel.freeSpaceAfterDescription == "1 KB")
        #expect(viewModel.cleanableSizeDescription == "300 bytes")
        #expect(viewModel.selectedSizeDescription == "100 bytes")
        #expect(viewModel.hasCleanupSummary == false)
        #expect(viewModel.isLoading == false)
    }

    @Test func `Given a service failure, when scanning, then the error is displayed`() async {
        let service = MockCleanupService(error: TestError.failed)
        let viewModel = CleanupViewModel(service: service)

        await viewModel.scan()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func `Given selected caches, when cleanup succeeds, then the summary updates and selection clears`() async {
        let service = MockCleanupService(scanResult: .fixture, cleanResult: .cleanedFixture)
        let viewModel = CleanupViewModel(service: service)
        await viewModel.scan()

        await viewModel.confirmCleanup()

        #expect(viewModel.resultMessage == "Cleanup reclaimed 100 bytes.")
        #expect(viewModel.freeBytesBefore == 1_000)
        #expect(viewModel.freeBytesAfter == 1_100)
        #expect(viewModel.freeBytesReclaimed == 100)
        #expect(viewModel.reclaimedSpaceDescription == "100 bytes")
        #expect(viewModel.hasCleanupSummary)
        #expect(viewModel.selectedCategoryIDs.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test func `Given cleaned caches, when cleanup completes, then remaining sizes are displayed`() async throws {
        let service = MockCleanupService(scanResult: .fixture, cleanResult: .cleanedFixture)
        let viewModel = CleanupViewModel(service: service)
        await viewModel.scan()

        await viewModel.confirmCleanup()

        let cleanedCategory = try #require(viewModel.categories.first)
        #expect(viewModel.sizeDescription(for: cleanedCategory) == "Zero KB")
    }

    @Test func `Given a pending service, when scanning, then loading reflects its lifetime`() async {
        let service = BlockingCleanupService()
        let viewModel = CleanupViewModel(service: service)

        let scanTask = Task { await viewModel.scan() }
        await Task.yield()

        #expect(viewModel.isLoading)

        await service.finishScan()
        await scanTask.value
        #expect(viewModel.isLoading == false)
    }

    @Test func `Given nonempty categories, when selecting all twice, then selection toggles off`() async {
        let service = MockCleanupService(scanResult: .fixture)
        let viewModel = CleanupViewModel(service: service)
        await viewModel.scan()
        viewModel.setCategory("xcode-derived-data", isSelected: false)

        viewModel.toggleSelectAll()

        #expect(viewModel.selectedCategoryIDs == ["xcode-derived-data", "simulator-contents"])
        #expect(viewModel.areAllCategoriesSelected)
        #expect(viewModel.selectAllButtonTitle == "Deselect All")

        viewModel.toggleSelectAll()

        #expect(viewModel.selectedCategoryIDs.isEmpty)
        #expect(viewModel.selectAllButtonTitle == "Select All")
    }

    @Test func `Given empty categories, when selecting all, then empty categories stay unselected`() async {
        let service = MockCleanupService(scanResult: .fixtureWithEmptyCategory)
        let viewModel = CleanupViewModel(service: service)
        await viewModel.scan()
        viewModel.setCategory("xcode-derived-data", isSelected: false)

        viewModel.toggleSelectAll()

        #expect(viewModel.selectedCategoryIDs == ["xcode-derived-data"])
    }
    @Test func `Given user selections, when rescanning, then choices remain unchanged`() async {
        let vm = CleanupViewModel(service: MockCleanupService(scanResult: .fixture))
        await vm.scan()
        vm.setCategory("xcode-derived-data", isSelected: false)
        vm.setCategory("simulator-contents", isSelected: true)
        await vm.scan()
        #expect(vm.selectedCategoryIDs == ["simulator-contents"])
    }
    @Test func `Given a blocked category, when cleanup completes, then its reason is displayed`() async {
        let report = CleanupReport(mode: "clean", freeBytesBefore: 1000, freeBytesAfter: 1000, freeBytesReclaimed: 0,
            categories: [CleanupCategory(id: "xcode-derived-data", name: "Xcode", path: "/safe", safeDefault: true, warning: "",
                bytesBefore: 100, bytesAfter: 100, status: .blocked, message: "Xcode is running")])
        let vm = CleanupViewModel(service: MockCleanupService(scanResult: .fixture, cleanResult: report))
        await vm.scan(); await vm.confirmCleanup()
        #expect(vm.errorMessage?.contains("Xcode is running") == true)
        #expect(vm.resultMessage?.contains("skipped") == true)
    }

}

private struct MockCleanupService: CleanupServiceProtocol {
    let scanResult: CleanupReport?
    let cleanResult: CleanupReport?
    let error: Error?

    init(
        scanResult: CleanupReport? = nil,
        cleanResult: CleanupReport? = nil,
        error: Error? = nil
    ) {
        self.scanResult = scanResult
        self.cleanResult = cleanResult
        self.error = error
    }

    func scan() async throws -> CleanupReport {
        if let error { throw error }
        return scanResult ?? .fixture
    }

    func clean(categoryIDs: Set<String>) async throws -> CleanupReport {
        if let error { throw error }
        return cleanResult ?? .cleanedFixture
    }
}

private enum TestError: Error {
    case failed
}

private actor BlockingCleanupService: CleanupServiceProtocol {
    private var scanContinuation: CheckedContinuation<CleanupReport, Never>?

    func scan() async throws -> CleanupReport {
        await withCheckedContinuation { continuation in
            scanContinuation = continuation
        }
    }

    func clean(categoryIDs: Set<String>) async throws -> CleanupReport {
        .cleanedFixture
    }

    func finishScan() {
        scanContinuation?.resume(returning: .fixture)
        scanContinuation = nil
    }
}

private extension CleanupReport {
    static let fixture = CleanupReport(
        mode: "scan",
        freeBytesBefore: 1_000,
        freeBytesAfter: 1_000,
        freeBytesReclaimed: 0,
        categories: [
            CleanupCategory(
                id: "xcode-derived-data",
                name: "Safe",
                path: "/safe",
                safeDefault: true,
                warning: "",
                bytesBefore: 100,
                bytesAfter: 100
            ),
            CleanupCategory(
                id: "simulator-contents",
                name: "Optional",
                path: "/optional",
                safeDefault: false,
                warning: "Warning",
                bytesBefore: 200,
                bytesAfter: 200
            )
        ]
    )

    static let fixtureWithEmptyCategory = CleanupReport(
        mode: "scan",
        freeBytesBefore: 1_000,
        freeBytesAfter: 1_000,
        freeBytesReclaimed: 0,
        categories: [
            CleanupCategory(
                id: "xcode-derived-data",
                name: "Safe",
                path: "/safe",
                safeDefault: true,
                warning: "",
                bytesBefore: 100,
                bytesAfter: 100
            ),
            CleanupCategory(
                id: "npm-cache",
                name: "Empty",
                path: "/empty",
                safeDefault: false,
                warning: "",
                bytesBefore: 0,
                bytesAfter: 0
            )
        ]
    )

    static let cleanedFixture = CleanupReport(
        mode: "clean",
        freeBytesBefore: 1_000,
        freeBytesAfter: 1_100,
        freeBytesReclaimed: 100,
        categories: [
            CleanupCategory(
                id: "xcode-derived-data",
                name: "Safe",
                path: "/safe",
                safeDefault: true,
                warning: "",
                bytesBefore: 100,
                bytesAfter: 0,
                bytesReclaimed: 100,
                status: .cleaned,
                message: "Cleanup completed."
            )
        ]
    )
}
