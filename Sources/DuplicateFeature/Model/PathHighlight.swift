import Foundation

/// Splits a duplicate copy's folder path into the part shared by every copy in its group and the part that
/// tells the copies apart, so the distinguishing folders can be emphasised. Pure presentation data.
struct PathHighlight: Equatable {
    let shared: String
    let distinct: String

    static func make(for path: String, among paths: [String]) -> PathHighlight {
        make(for: path, commonFolderCount: commonFolderCount(paths))
    }

    /// Number of leading folders every path shares. Compute once per group: O(paths × depth).
    static func commonFolderCount(_ paths: [String]) -> Int {
        guard let first = paths.first.map(directoryComponents) else { return 0 }
        var common = first.count
        for path in paths.dropFirst() {
            let folders = directoryComponents(path)
            var index = 0
            while index < min(common, folders.count), folders[index] == first[index] { index += 1 }
            common = index
            if common == 0 { break }
        }
        return common
    }

    static func make(for path: String, commonFolderCount common: Int) -> PathHighlight {
        let own = directoryComponents(path)
        let sharedPart = own.prefix(common).joined(separator: "/")
        let distinctPart = own.dropFirst(common).joined(separator: "/")
        let prefix = path.hasPrefix("/") ? "/" : ""
        let shared = sharedPart.isEmpty ? prefix : prefix + sharedPart + "/"
        return PathHighlight(shared: shared, distinct: distinctPart.isEmpty ? "" : distinctPart + "/")
    }

    private static func directoryComponents(_ path: String) -> [String] {
        Array(path.split(separator: "/").dropLast().map(String.init))
    }
}
