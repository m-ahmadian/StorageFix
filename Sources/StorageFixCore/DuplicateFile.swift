import Foundation

public struct DuplicateFile: Identifiable, Equatable, Sendable {
    public let path: String
    public let bytes: Int64
    public let modifiedAt: Date?
    public let fileIdentity: String?
    public let allocatedBytes: Int64?
    public let isSharedLink: Bool
    public let mayShareContent: Bool?
    public var id: String { path }
    public init(path: String, bytes: Int64, modifiedAt: Date? = nil, fileIdentity: String? = nil, allocatedBytes: Int64? = nil, isSharedLink: Bool = false, mayShareContent: Bool? = nil) {
        self.path = path; self.bytes = bytes; self.modifiedAt = modifiedAt; self.fileIdentity = fileIdentity
        self.allocatedBytes = allocatedBytes; self.isSharedLink = isSharedLink; self.mayShareContent = mayShareContent
    }
}

public struct DuplicateGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let original: DuplicateFile
    public let duplicates: [DuplicateFile]
    public init(id: String, original: DuplicateFile, duplicates: [DuplicateFile]) { self.id = id; self.original = original; self.duplicates = duplicates }
}
