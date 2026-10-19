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
    /// True when cleaning moves items to the Trash instead of deleting them.
    public let movesToTrash: Bool
    /// Names of the individual items for categories made of separate files (installers, app leftovers).
    public let items: [String]

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
        message: String = "",
        movesToTrash: Bool = false,
        items: [String] = []
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
        self.movesToTrash = movesToTrash
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, safeDefault, warning, bytesBefore, bytesAfter, bytesReclaimed, status, message, movesToTrash, items
    }

    /// Older reports (and the direct edition's script) omit the newer keys.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path); safeDefault = try c.decode(Bool.self, forKey: .safeDefault)
        warning = try c.decode(String.self, forKey: .warning); bytesBefore = try c.decode(Int64.self, forKey: .bytesBefore)
        bytesAfter = try c.decode(Int64.self, forKey: .bytesAfter); bytesReclaimed = try c.decode(Int64.self, forKey: .bytesReclaimed)
        status = try c.decode(CleanupStatus.self, forKey: .status); message = try c.decode(String.self, forKey: .message)
        movesToTrash = try c.decodeIfPresent(Bool.self, forKey: .movesToTrash) ?? false
        items = try c.decodeIfPresent([String].self, forKey: .items) ?? []
    }
}
