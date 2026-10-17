import Foundation

public struct CleanupCategory: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let safeDefault: Bool
    public let warning: String
    public let bytesBefore: Int64
    public let bytesAfter: Int64
    public let bytesReclaimed: Int64
    public let status: CleanupStatus
    public let message: String

    public init(
        id: String,
        name: String,
        path: String,
        safeDefault: Bool,
        warning: String,
        bytesBefore: Int64,
        bytesAfter: Int64 = 0,
        bytesReclaimed: Int64 = 0,
        status: CleanupStatus = .scanned,
        message: String = ""
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.safeDefault = safeDefault
        self.warning = warning
        self.bytesBefore = bytesBefore
        self.bytesAfter = bytesAfter
        self.bytesReclaimed = bytesReclaimed
        self.status = status
        self.message = message
    }
}
