import Foundation

public struct ReviewAreaResult: Identifiable, Equatable, Sendable {
    public let section: WorkspaceSection
    public let scope: String
    public let itemCount: Int?
    public let bytes: Int64?
    public let error: String?
    public var id: WorkspaceSection { section }
}
