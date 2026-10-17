import Foundation

/// The guided storage-review journey. Progress is derived from observed state; it never selects or authorizes files.
public enum JourneyStage: Int, CaseIterable, Identifiable, Sendable {
    case choose, understand, inspect, queue, verify
    public var id: Int { rawValue }
    public var title: String {
        switch self {
        case .choose: "Choose"
        case .understand: "Understand"
        case .inspect: "Inspect"
        case .queue: "Review queue"
        case .verify: "Verify"
        }
    }
    var section: WorkspaceSection {
        switch self {
        case .choose: .overview
        case .understand: .map
        case .inspect: .files
        case .queue: .queue
        case .verify: .overview
        }
    }
}

public struct ReviewJourney: Equatable, Sendable {
    public struct Inputs: Equatable, Sendable {
        public var hasResults = false
        public var hasExplored = false
        public var queuedCount = 0
        public var lastRunDate: Date?
        public var lastReviewDate: Date?
        public init(hasResults: Bool = false, hasExplored: Bool = false, queuedCount: Int = 0,
                    lastRunDate: Date? = nil, lastReviewDate: Date? = nil) {
            self.hasResults = hasResults; self.hasExplored = hasExplored; self.queuedCount = queuedCount
            self.lastRunDate = lastRunDate; self.lastReviewDate = lastReviewDate
        }
    }

    /// nil once the latest outcome was verified by a fresh scan.
    public let current: JourneyStage?

    public init(_ inputs: Inputs) { current = Self.stage(for: inputs) }

    public func isComplete(_ stage: JourneyStage) -> Bool {
        guard let current else { return true }
        return stage.rawValue < current.rawValue
    }

    private static func stage(for inputs: Inputs) -> JourneyStage? {
        if inputs.queuedCount > 0 { return .queue }
        if let run = inputs.lastRunDate {
            guard let review = inputs.lastReviewDate, review > run else { return .verify }
            return nil
        }
        if inputs.hasExplored { return .inspect }
        return inputs.hasResults ? .understand : .choose
    }
}
