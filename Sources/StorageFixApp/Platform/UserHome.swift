import Darwin
import Foundation

/// The person's real Home folder. Inside the sandbox `homeDirectoryForCurrentUser` points at the app container.
enum UserHome {
    static var real: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
