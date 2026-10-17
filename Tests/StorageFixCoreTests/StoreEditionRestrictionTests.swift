import Foundation
import StorageFixCore
import Testing

#if APP_STORE
struct StoreEditionRestrictionTests {
    @Test
    func `Store edition refuses script cleanup without launching a process`() async {
        let service = ScriptCleanupService(scriptURL: URL(fileURLWithPath: "/unavailable/script.sh"))
        do {
            _ = try await service.scan()
            Issue.record("Store edition must not run script scans")
        } catch CleanupServiceError.unavailable {
            // The edition restriction is evaluated before any process or file read.
        } catch { Issue.record("Expected the Store edition restriction; got \(error)") }
    }
}

#endif
