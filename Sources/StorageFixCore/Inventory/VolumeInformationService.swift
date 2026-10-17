import Foundation

public protocol VolumeInformationServiceProtocol: Sendable {
    func volume(at root: URL) -> InventoryVolume?
}

public struct VolumeInformationService: VolumeInformationServiceProtocol {
    private let source: any InventoryMetadataSource
    public init(source: any InventoryMetadataSource) { self.source = source }
    public func volume(at root: URL) -> InventoryVolume? { source.volume(at: root) }
}
