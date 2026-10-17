import DuplicateFeature
import Foundation
import StorageFixCore
import Testing

@MainActor struct DuplicatePreviewTests {
    @Test func `Kept and matching copies can be previewed but unknown paths cannot`() async throws {
        let presenter = PreviewRecorder()
        let controlled = DuplicateViewModel(service: PreviewDuplicates(), presenter: presenter)
        await controlled.scan()
        controlled.preview("/fixture/old"); controlled.preview("/fixture/new"); controlled.preview("/unreviewed")
        #expect(presenter.paths == ["/fixture/old", "/fixture/new"])
        let group = try #require(controlled.groups.first)
        #expect(controlled.suggestion(in: group)?.contains("new") == true)
        #expect(controlled.selectedPaths.isEmpty && controlled.groups.first?.original.path == "/fixture/old")
        controlled.keep(path: "/fixture/new", in: group.id)
        #expect(controlled.selectedPaths.isEmpty && controlled.groups.first?.original.path == "/fixture/new")
    }
}
private struct PreviewDuplicates: DuplicateServiceProtocol {
    func scan() async throws -> [DuplicateGroup] {
        [.init(id: "digest", original: .init(path: "/fixture/old", bytes: 10, modifiedAt: .distantPast),
               duplicates: [.init(path: "/fixture/new", bytes: 10, modifiedAt: Date(timeIntervalSince1970: 100))])]
    }
    func remove(paths: Set<String>) async throws {}
    func reveal(path: String) {}
}
@MainActor private final class PreviewRecorder: FilePresentationCoordinating {
    var paths: [String] = []
    func preview(_ url: URL) { paths.append(url.path) }
    func reveal(_ url: URL) {}
}
