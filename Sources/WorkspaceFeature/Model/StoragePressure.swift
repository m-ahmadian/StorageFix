import Foundation

/// How full the reviewed volume is. Drives the capacity ring colour and a short status line.
public enum StoragePressure: Equatable, Sendable {
    case unknown, comfortable, tight, critical

    static let tightThreshold = 0.85
    static let criticalThreshold = 0.95

    init(usedFraction: Double?) {
        guard let usedFraction else { self = .unknown; return }
        switch usedFraction {
        case Self.criticalThreshold...: self = .critical
        case Self.tightThreshold...: self = .tight
        default: self = .comfortable
        }
    }

    var status: String? {
        switch self {
        case .unknown, .comfortable: nil
        case .tight: "Getting full"
        case .critical: "Almost full"
        }
    }
}
