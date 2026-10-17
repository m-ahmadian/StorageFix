import Foundation

/// Splits a duplicate copy's folder path into the part shared by every copy in its group and the part that
/// tells the copies apart, so the distinguishing folders can be emphasised. Pure presentation data.
struct PathHighlight: Equatable {
    let shared: String
    let distinct: String

    static func make(for path: String, among paths: [String]) -> PathHighlight {
        let folders = paths.map { directoryComponents($0) }
        let own = directoryComponents(path)
        var common = 0
        while let first = folders.first, common < first.count,
              folders.allSatisfy({ $0.count > common && $0[common] == first[common] }) {
            common += 1
        }
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
