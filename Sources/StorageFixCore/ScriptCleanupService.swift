#if APP_STORE
import Foundation
public struct ScriptCleanupService: CleanupServiceProtocol {
    public init(scriptURL: URL, scanTimeout: Duration = .seconds(120)) {}
    public func scan() async throws -> CleanupReport { throw CleanupServiceError.unavailable }
    public func clean(categoryIDs: Set<String>) async throws -> CleanupReport { throw CleanupServiceError.unavailable }
}
public enum CleanupServiceError: Error, LocalizedError {
    case unavailable
    public var errorDescription: String? { "System cache cleanup is not included in the sandboxed edition." }
}
#else
import Darwin
import Foundation

public struct ScriptCleanupService: CleanupServiceProtocol {
    private let scriptURL: URL
    private let scanTimeout: Duration
    public init(scriptURL: URL, scanTimeout: Duration = .seconds(120)) { self.scriptURL = scriptURL; self.scanTimeout = scanTimeout }
    public func scan() async throws -> CleanupReport { try await run(arguments: ["--scan", "--format", "json"], timeout: scanTimeout) }
    public func clean(categoryIDs: Set<String>) async throws -> CleanupReport {
        try await run(arguments: ["--clean"] + categoryIDs.sorted() + ["--format", "json"])
    }
    private func run(arguments: [String], timeout: Duration? = nil) async throws -> CleanupReport {
        // Files avoid pipe-buffer deadlocks. An owned process group lets cancellation
        // stop only this operation and its descendants, including a long-running du.
        let folder = FileManager.default.temporaryDirectory.appending(path: "StorageFix-process-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let outputURL = folder.appending(path: "stdout"), errorURL = folder.appending(path: "stderr")
        let outputFD = open(outputURL.path, O_CREAT | O_WRONLY | O_TRUNC, 0o600)
        let errorFD = open(errorURL.path, O_CREAT | O_WRONLY | O_TRUNC, 0o600)
        guard outputFD >= 0, errorFD >= 0 else {
            if outputFD >= 0 { close(outputFD) }; if errorFD >= 0 { close(errorFD) }
            throw CleanupServiceError.scriptFailed("Cannot prepare the cleanup report.")
        }
        defer { close(outputFD); close(errorFD) }
        var actions: posix_spawn_file_actions_t?; var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions); posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outputFD, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, errorFD, STDERR_FILENO)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)
        let argv = (["/bin/zsh", scriptURL.path] + arguments).map { strdup($0) } + [nil]
        let envp = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var pid: pid_t = 0
        try Task.checkCancellation()
        let result = argv.withUnsafeBufferPointer { args in envp.withUnsafeBufferPointer { env in
            posix_spawn(&pid, "/bin/zsh", &actions, &attributes, UnsafeMutablePointer(mutating: args.baseAddress!), UnsafeMutablePointer(mutating: env.baseAddress!))
        } }
        guard result == 0 else { throw CleanupServiceError.scriptFailed("Could not start cleanup: \(String(cString: strerror(result)))") }
        var status: Int32 = 0
        let started = ContinuousClock.now
        do {
            while true {
                try Task.checkCancellation()
                if let timeout, started.duration(to: .now) >= timeout { throw CleanupServiceError.scriptFailed("Cache scan took too long. Try again, or explore a smaller folder in Storage Map.") }
                let waited = waitpid(pid, &status, WNOHANG)
                if waited == pid { break }
                if waited < 0 && errno != EINTR { throw CleanupServiceError.scriptFailed("Cannot read cleanup status.") }
                try await Task.sleep(for: .milliseconds(25))
            }
        } catch {
            kill(-pid, SIGKILL) // The group belongs exclusively to this scan/cleanup.
            while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
            throw error
        }
        let exitCode = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        let errorMessage = String(decoding: (try? Data(contentsOf: errorURL)) ?? Data(), as: UTF8.self)
        guard [0, 1, 75].contains(exitCode) else { throw CleanupServiceError.scriptFailed(errorMessage) }
        do {
            let report = try JSONDecoder().decode(CleanupReport.self, from: Data(contentsOf: outputURL))
            if exitCode == 1 && !report.categories.contains(where: { $0.status == .failed }) { throw CleanupServiceError.scriptFailed(errorMessage) }
            return report
        } catch let error as CleanupServiceError { throw error }
        catch { if exitCode != 0 { throw CleanupServiceError.scriptFailed(errorMessage) }; throw CleanupServiceError.invalidOutput }
    }
}
public enum CleanupServiceError: Error, LocalizedError {
    case invalidOutput, scriptFailed(String)
    public var errorDescription: String? {
        switch self {
        case .invalidOutput: "The cleanup script returned invalid output."
        case .scriptFailed(let message): message.isEmpty ? "The cleanup script failed." : message
        }
    }
}

#endif
