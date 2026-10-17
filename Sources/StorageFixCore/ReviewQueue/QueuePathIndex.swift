import Foundation

struct QueuePathIndex {
    private var paths: Set<String> = []
    private var ancestors: Set<String> = []
    init(paths: [String] = []) { for path in paths { insert(path) } }
    mutating func insert(_ path: String) {
        paths.insert(path)
        for parent in Self.parents(of: path) { ancestors.insert(parent) }
    }
    func overlaps(_ path: String) -> Bool {
        ancestors.contains(path) || Self.parents(of: path).contains { paths.contains($0) }
    }
    private static func parents(of path: String) -> [String] {
        var url = URL(fileURLWithPath: path).deletingLastPathComponent()
        var result: [String] = []
        while url.path != "/" && !url.path.isEmpty {
            result.append(url.path); url = url.deletingLastPathComponent()
        }
        result.append("/")
        return result
    }
}
