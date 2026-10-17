import Darwin
import Foundation
import StorageFixCore
import Testing

@Suite(.enabled(if: DistributionMode.current == .direct))
struct ScriptCleanupServiceTests {
    @Test func `Given valid script output, when scanning, then the report is decoded`() async throws {
        let scriptURL = try makeScript(
            output: #"{"mode":"scan","freeBytesBefore":100,"freeBytesAfter":100,"freeBytesReclaimed":0,"categories":[]}"#
        )
        let service = ScriptCleanupService(scriptURL: scriptURL)

        let report = try await service.scan()

        #expect(report.mode == "scan")
        #expect(report.categories.isEmpty)
    }

    @Test func `Given a failing script, when scanning, then the failure is reported`() async throws {
        let scriptURL = try makeScript(output: "", exitCode: 1)
        let service = ScriptCleanupService(scriptURL: scriptURL)

        await #expect(throws: CleanupServiceError.self) {
            try await service.scan()
        }
    }

    @Test func `Given partial cleanup failures, when the script exits with failure, then category results remain available`() async throws {
        let script = try makeScript(output: #"{"mode":"clean","freeBytesBefore":100,"freeBytesAfter":100,"freeBytesReclaimed":0,"categories":[{"id":"app-logs","name":"Logs","path":"/logs","safeDefault":true,"warning":"","bytesBefore":100,"bytesAfter":100,"bytesReclaimed":0,"status":"failed","message":"Permission denied"}]}"#, exitCode: 1)
        let report = try await ScriptCleanupService(scriptURL: script).clean(categoryIDs: ["app-logs"])
        #expect(report.categories.first?.status == .failed)
    }
    @Test func `Given a report larger than a pipe buffer, when scanning, then the process completes without deadlock`() async throws {
        let output = #"{"mode":"scan","freeBytesBefore":100,"freeBytesAfter":100,"freeBytesReclaimed":0,"categories":[]}"# + String(repeating: " ", count: 200_000)
        let script = try makeScript(output: output)
        #expect(try await ScriptCleanupService(scriptURL: script).scan().mode == "scan")
    }

    @Test func `Given a slow child process, when scanning is cancelled, then cancellation returns promptly and stops descendants`() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let started = folder.appending(path: "started"), childPID = folder.appending(path: "child-pid")
        let script = folder.appending(path: "slow.sh")
        try "#!/bin/zsh\n/bin/sleep 30 &\nprint $! > '\(childPID.path)'\nprint ready > '\(started.path)'\nwait\n".write(to: script, atomically: true, encoding: .utf8)
        let task = Task { try await ScriptCleanupService(scriptURL: script).scan() }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: started.path) { try await Task.sleep(for: .milliseconds(20)) }
        #expect(FileManager.default.fileExists(atPath: started.path))
        let start = ContinuousClock.now; task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(start.duration(to: .now) < .seconds(2))
        let pid = try #require(Int32(String(contentsOf: childPID, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        try await Task.sleep(for: .milliseconds(50))
        #expect(kill(pid, 0) == -1)
    }

    @Test func `Given an excessively slow scan, when its time limit is reached, then a recoverable error replaces indefinite loading`() async throws {
        let script = try makeScript(output: "")
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        try "#!/bin/zsh\n/bin/sleep 30\n".write(to: script, atomically: true, encoding: .utf8)
        let start = ContinuousClock.now
        await #expect(throws: CleanupServiceError.self) { try await ScriptCleanupService(scriptURL: script, scanTimeout: .milliseconds(100)).scan() }
        #expect(start.duration(to: .now) < .seconds(2))
    }

    private func makeScript(output: String, exitCode: Int = 0) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scriptURL = directory.appending(path: "mock.sh")
        let script = "#!/bin/zsh\nprint -r -- '\(output)'\nexit \(exitCode)\n"
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        return scriptURL
    }
}
