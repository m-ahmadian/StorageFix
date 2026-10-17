import StorageFixCore
import SwiftUI

public struct QueueAddResultView: View {
    private let result: ReviewQueueAddResult
    public init(result: ReviewQueueAddResult) { self.result = result }
    public var body: some View {
        if !result.rejections.isEmpty {
            DisclosureGroup("\(result.rejections.count) files were not added") {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        ForEach(result.rejections.keys.sorted(), id: \.self) { path in
                            Text(path).font(.caption.weight(.semibold)).textSelection(.enabled)
                            Text(result.rejections[path] ?? "").font(.caption)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: DesignSystem.Size.coverageDetailsHeight)
            }.padding(DesignSystem.Spacing.medium).workspaceCard()
        }
    }
}
