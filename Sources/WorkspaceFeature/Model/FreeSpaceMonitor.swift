import Foundation

/// Free space on the startup volume for the menu bar, refreshed once a minute. Reading capacity changes nothing.
@MainActor
public final class FreeSpaceMonitor: ObservableObject {
    @Published public private(set) var availableBytes: Int64?
    @Published public private(set) var capacityBytes: Int64?
    private let read: @Sendable () -> (available: Int64?, capacity: Int64?)
    private var timer: Timer?
    private let formatter: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()
    /// Below either limit the menu bar icon warns.
    static let lowFraction = 0.10
    static let lowBytes: Int64 = 15_000_000_000

    public init(read: @escaping @Sendable () -> (available: Int64?, capacity: Int64?), refreshInterval: TimeInterval? = 60) {
        self.read = read
        refresh()
        if let refreshInterval {
            timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    /// Reads the volume that holds `url` (the Home folder's volume is the startup disk on almost every Mac).
    public static func volume(at url: URL) -> @Sendable () -> (available: Int64?, capacity: Int64?) {
        {
            let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            let available = values?.volumeAvailableCapacityForImportantUsage ?? values?.volumeAvailableCapacity.map(Int64.init)
            return (available, values?.volumeTotalCapacity.map(Int64.init))
        }
    }

    public func refresh() {
        let value = read()
        availableBytes = value.available; capacityBytes = value.capacity
    }

    /// Short label for the menu bar, for example "41.8 GB".
    public var title: String { availableBytes.map { formatter.string(fromByteCount: $0) } ?? "—" }
    public var capacityTitle: String { capacityBytes.map { formatter.string(fromByteCount: $0) } ?? "—" }
    public var usedFraction: Double {
        guard let availableBytes, let capacityBytes, capacityBytes > 0 else { return 0 }
        return min(1, max(0, 1 - Double(availableBytes) / Double(capacityBytes)))
    }
    public var isLow: Bool {
        guard let availableBytes else { return false }
        if availableBytes < Self.lowBytes { return true }
        guard let capacityBytes, capacityBytes > 0 else { return false }
        return Double(availableBytes) / Double(capacityBytes) < Self.lowFraction
    }
}
