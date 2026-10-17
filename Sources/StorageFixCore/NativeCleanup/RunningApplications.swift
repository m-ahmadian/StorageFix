import AppKit

public protocol RunningApplicationsProviding: Sendable {
    func runningBundleIdentifiers() async -> Set<String>
}

public struct WorkspaceRunningApplications: RunningApplicationsProviding {
    public init() {}
    public func runningBundleIdentifiers() async -> Set<String> {
        await MainActor.run { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
    }
}

public enum NativeCleanupError: LocalizedError, Equatable, Sendable {
    case accessRequired(String)
    case wrongFolder(String)
    public var errorDescription: String? {
        switch self {
        case .accessRequired(let path): "Allow access to your Home folder (\(path)) so StorageFix can measure and clean caches."
        case .wrongFolder(let path): "Choose your Home folder (\(path)). Cache cleanup only works inside it."
        }
    }
}
