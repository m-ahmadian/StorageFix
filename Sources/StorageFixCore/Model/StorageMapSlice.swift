public struct StorageMapSlice: Identifiable, Equatable, Sendable {
    public enum ID: Hashable, Sendable {
        case item(String)
        case remainder
    }

    public let id: ID
    public let name: String
    public let bytes: Int64
    public let itemCount: Int
    public init(id: ID, name: String, bytes: Int64, itemCount: Int) {
        self.id = id; self.name = name; self.bytes = bytes; self.itemCount = itemCount
    }
}
