import Combine
import Foundation

@MainActor public protocol ScanComparisonSessionProtocol: AnyObject {
    var currentScan: InventoryScan? { get }
    var updates: AnyPublisher<InventoryScan?, Never> { get }
    func receive(_ scan: InventoryScan?)
}

/// App-owned session state; imported snapshots never feed the live inventory or review queue.
@MainActor public final class ScanComparisonSession: ScanComparisonSessionProtocol {
    @Published public private(set) var currentScan: InventoryScan?
    public var updates: AnyPublisher<InventoryScan?, Never> { $currentScan.eraseToAnyPublisher() }
    public init() {}
    public func receive(_ scan: InventoryScan?) { currentScan = scan }
}
