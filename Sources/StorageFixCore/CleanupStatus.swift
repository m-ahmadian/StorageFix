public enum CleanupStatus: String, Codable, Sendable {
    case scanned
    case cleaned
    case blocked
    case failed
}
