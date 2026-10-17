import Foundation

public struct ReviewReport: Equatable, Sendable {
    public let date: Date
    public let folder: String
    public let areas: [ReviewAreaResult]
    public let availableBytes: Int64?
    public let capacityBytes: Int64?
}
