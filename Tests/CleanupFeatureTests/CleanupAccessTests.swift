import CleanupFeature
import Foundation
import StorageFixCore
import Testing

actor AccessRequiringCleanup: CleanupServiceProtocol {
    nonisolated let requiredFolder: URL? = URL(fileURLWithPath: "/Users/example")
    private(set) var granted = false
    private(set) var scans = 0
    var hasAccess: Bool { get async { granted } }
    func grantAccess(to folder: URL) async throws {
        guard folder.path == "/Users/example" else { throw NativeCleanupError.wrongFolder("/Users/example") }
        granted = true
    }
    func scan() async throws -> CleanupReport {
        scans += 1
        return CleanupReport(mode: "scan", freeBytesBefore: 100, freeBytesAfter: 100, freeBytesReclaimed: 0, categories: [
            CleanupCategory(id: "google-cache", name: "Google", path: "~/Library/Caches/Google", safeDefault: true, warning: "", bytesBefore: 500, bytesAfter: 500)])
    }
    func clean(categoryIDs: Set<String>) async throws -> CleanupReport { try await scan() }
}

@MainActor struct CleanupAccessTests {
    @Test func `Until Home is granted, cleanup does not scan and asks for access`() async {
        let service = AccessRequiringCleanup()
        let vm = CleanupViewModel(service: service)
        #expect(vm.needsAccess && vm.requiredFolder?.path == "/Users/example")
        await vm.scan()
        #expect(await service.scans == 0 && !vm.hasScanned && vm.errorMessage == nil)
    }

    @Test func `Choosing the wrong folder explains the requirement; choosing Home scans with safe defaults selected`() async {
        let service = AccessRequiringCleanup()
        let vm = CleanupViewModel(service: service)
        await vm.grantAccess(to: URL(fileURLWithPath: "/Users/example/Downloads"))
        #expect(vm.needsAccess && vm.errorMessage?.contains("Home folder") == true)
        await vm.grantAccess(to: URL(fileURLWithPath: "/Users/example"))
        #expect(!vm.needsAccess && vm.hasScanned && vm.selectedBytes == 500)
    }

    @Test func `A folder offered from Quick Review grants access only when it is Home`() async {
        let vm = CleanupViewModel(service: AccessRequiringCleanup())
        await vm.offerFolder(URL(fileURLWithPath: "/Users/example/Documents"))
        #expect(vm.needsAccess)
        await vm.offerFolder(URL(fileURLWithPath: "/Users/example"))
        #expect(!vm.needsAccess && vm.errorMessage == nil)
    }
}
