public struct CleanupReport: Codable, Equatable, Sendable {
    public let mode: String
    public let freeBytesBefore: Int64
    public let freeBytesAfter: Int64
    public let freeBytesReclaimed: Int64
    public let categories: [CleanupCategory]

    public init(
        mode: String,
        freeBytesBefore: Int64,
        freeBytesAfter: Int64,
        freeBytesReclaimed: Int64,
        categories: [CleanupCategory]
    ) {
        self.mode = mode
        self.freeBytesBefore = freeBytesBefore
        self.freeBytesAfter = freeBytesAfter
        self.freeBytesReclaimed = freeBytesReclaimed
        self.categories = categories
    }
}
