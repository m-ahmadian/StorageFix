import Foundation
import StorageFixCore

/// Synthetic content only, used to render the shipping Store interface.
enum StoreScreenshotFixtures {
    static let root = URL(fileURLWithPath: "/Sample Library")
    static let original = DuplicateFile(path: "/Sample Library/Documents/Project Brief.pdf", bytes: 20_000_000)
    static let copy = DuplicateFile(path: "/Sample Library/Downloads/Project Brief Copy.pdf", bytes: 20_000_000)
    static let inventory = [original, copy,
        DuplicateFile(path: "/Sample Library/Exports/Travel Film.mov", bytes: 240_000_000),
        DuplicateFile(path: "/Sample Library/Images/Photo Archive.zip", bytes: 120_000_000)]

    struct Files: FileBrowserServiceProtocol {
        func scan(in root: URL) async throws -> [DuplicateFile] { StoreScreenshotFixtures.inventory }
        func moveToTrash(paths: Set<String>) async throws {}
    }
    struct Duplicates: DuplicateServiceProtocol {
        func scan() async throws -> [DuplicateGroup] {
            [DuplicateGroup(id: "brief", original: original, duplicates: [copy])]
        }
        func remove(paths: Set<String>) async throws {}
        func reveal(path: String) {}
    }
}
