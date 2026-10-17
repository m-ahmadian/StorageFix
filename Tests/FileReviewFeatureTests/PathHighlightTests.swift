@testable import DuplicateFeature
import Testing

struct PathHighlightTests {
    private let paths = ["/Users/a/Documents/Project/Brief.pdf", "/Users/a/Downloads/Brief.pdf", "/Users/a/Documents/Old/Brief.pdf"]

    @Test func `The folders that differ between copies are separated from the shared prefix`() {
        #expect(PathHighlight.make(for: paths[0], among: paths) == PathHighlight(shared: "/Users/a/", distinct: "Documents/Project/"))
        #expect(PathHighlight.make(for: paths[1], among: paths) == PathHighlight(shared: "/Users/a/", distinct: "Downloads/"))
    }

    @Test func `Copies in the same folder have nothing to emphasise`() {
        let same = ["/x/y/a.txt", "/x/y/b.txt"]
        #expect(PathHighlight.make(for: same[0], among: same) == PathHighlight(shared: "/x/y/", distinct: ""))
    }

    @Test func `A file at the root of a different volume is fully distinct`() {
        let mixed = ["/a.txt", "/Volumes/Disk/a.txt"]
        #expect(PathHighlight.make(for: mixed[1], among: mixed) == PathHighlight(shared: "/", distinct: "Volumes/Disk/"))
    }
}
