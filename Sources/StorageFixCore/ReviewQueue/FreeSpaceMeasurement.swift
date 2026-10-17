import Foundation

/// Observed free space on the queue's volume around an operation.
/// The whole-volume change is never attributed to the moved files.
public struct FreeSpaceMeasurement: Equatable, Sendable {
    public let beforeBytes: Int64?
    public let afterBytes: Int64?
    public let measuredAt: Date
    /// Present when free space could not be measured; explains why.
    public let unavailableReason: String?

    public init(beforeBytes: Int64?, afterBytes: Int64?, measuredAt: Date = Date(), unavailableReason: String? = nil) {
        self.beforeBytes = beforeBytes; self.afterBytes = afterBytes
        self.measuredAt = measuredAt; self.unavailableReason = unavailableReason
    }

    public static func unavailable(_ reason: String) -> FreeSpaceMeasurement {
        FreeSpaceMeasurement(beforeBytes: nil, afterBytes: nil, unavailableReason: reason)
    }

    public var isMeasured: Bool { unavailableReason == nil && changeBytes != nil }

    /// Positive when the volume reports more free space than before the operation.
    public var changeBytes: Int64? {
        guard let beforeBytes, let afterBytes else { return nil }
        let result = afterBytes.subtractingReportingOverflow(beforeBytes)
        return result.overflow ? nil : result.partialValue
    }

    func remeasured(afterBytes: Int64?, at date: Date) -> FreeSpaceMeasurement {
        guard beforeBytes != nil else { return self }
        guard let afterBytes else {
            return FreeSpaceMeasurement(beforeBytes: beforeBytes, afterBytes: nil, measuredAt: date,
                unavailableReason: FreeSpaceProbe.unreadable)
        }
        return FreeSpaceMeasurement(beforeBytes: beforeBytes, afterBytes: afterBytes, measuredAt: date)
    }
}

/// Reads available capacity for the single volume holding a queue batch.
struct FreeSpaceProbe {
    static let unreadable = "The volume did not report its free space."
    static let multipleVolumes = "Queued files appear to span more than one volume, so free space was not measured."
    let volumes: any VolumeInformationServiceProtocol

    /// Returns the measurement root, or a reason the batch cannot be measured as one volume.
    func target(for roots: [URL]) -> Result<URL, FreeSpaceProbeError> {
        let unique = Array(Set(roots.map(\.standardizedFileURL)))
        guard let first = unique.first else { return .failure(FreeSpaceProbeError(Self.unreadable)) }
        let names = unique.map { volumes.volume(at: $0)?.name }
        guard !names.contains(where: { $0 == nil }) else { return .failure(FreeSpaceProbeError(Self.unreadable)) }
        guard Set(names).count == 1 else { return .failure(FreeSpaceProbeError(Self.multipleVolumes)) }
        return .success(first)
    }

    func availableBytes(at root: URL) -> Int64? { volumes.volume(at: root)?.availableBytes }
}

struct FreeSpaceProbeError: Error, Equatable {
    let reason: String
    init(_ reason: String) { self.reason = reason }
}
