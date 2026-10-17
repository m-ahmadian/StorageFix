import Foundation

public struct ScanComparison: Equatable, Sendable {
    public enum Change: String, Sendable { case newlyObserved = "Newly observed", noLongerObserved = "No longer observed", metadataChanged = "Metadata changed" }
    public struct Item: Equatable, Identifiable, Sendable {
        public let path: String
        public let change: Change
        public let beforeBytes: Int64?
        public let afterBytes: Int64?
        public var id: String { path }
    }
    public let baselineID: UUID
    public let currentID: UUID
    public let beforeBytes: Int64
    public let afterBytes: Int64
    public let unchangedCount: Int
    public let warnings: [String]
    public let items: [Item]
    public var observedByteChange: Int64 { afterBytes - beforeBytes }
}

public enum ScanSnapshotError: LocalizedError, Equatable, Sendable {
    case invalidDocument, unsupportedVersion, tooLarge, differentScope, differentOptions
    public var errorDescription: String? {
        switch self {
        case .invalidDocument: "This is not a valid StorageFix scan snapshot."
        case .unsupportedVersion: "This snapshot uses an unsupported version."
        case .tooLarge: "This snapshot exceeds the supported size or entry limit."
        case .differentScope: "Choose and scan the same folder path as the baseline before comparing."
        case .differentOptions: "Use the baseline’s hidden-file and package-content options before comparing."
        }
    }
}
