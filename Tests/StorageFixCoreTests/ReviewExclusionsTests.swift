import StorageFixCore
import Testing

struct ReviewExclusionsTests {
    @Test(arguments: [
        ("/Users/a/Library/Caches/x.png", true), ("/Users/a/code/app/node_modules/lib/LICENSE", true),
        ("/Users/a/code/app/.build/debug/x", true), ("/Users/a/Pictures/Library.jpg", false),
        ("/Users/a/Documents/report.pdf", false), ("/Users/a/Downloads/venv-notes.txt", false)
    ])
    func `Library, dependency and build folders are skipped; ordinary files are kept`(path: String, excluded: Bool) {
        #expect(ReviewExclusions.excludes(path) == excluded)
    }
}
