import Foundation
import StorageFixCore

extension DuplicateViewModel {
    public var canPreview: Bool { presenter != nil && !isLoading && !isQueueBusy }
    public func preview(_ path: String) {
        guard canPreview, groups.contains(where: { ([$0.original] + $0.duplicates).contains { $0.path == path } }) else { return }
        presenter?.preview(URL(fileURLWithPath: path))
    }
    public func suggestion(in group: DuplicateGroup) -> String? {
        let members = [group.original] + group.duplicates
        guard members.allSatisfy({ $0.modifiedAt != nil }),
              let newest = members.max(by: { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }),
              let date = newest.modifiedAt, members.filter({ $0.modifiedAt == date }).count == 1 else { return nil }
        return "Most recently modified: \(URL(fileURLWithPath: newest.path).lastPathComponent). Inspect its location before choosing Keep This. No selection is applied."
    }
}
