import StorageFixCore
import SwiftUI

private struct FolderAccessKey: EnvironmentKey {
    static let defaultValue: (any FolderAccessSessionProtocol)? = nil
}

public extension EnvironmentValues {
    var folderAccessSession: (any FolderAccessSessionProtocol)? {
        get { self[FolderAccessKey.self] }
        set { self[FolderAccessKey.self] = newValue }
    }
}
