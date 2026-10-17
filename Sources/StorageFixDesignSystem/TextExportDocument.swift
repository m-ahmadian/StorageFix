import SwiftUI
import UniformTypeIdentifiers

public struct TextExportDocument: FileDocument {
    public static let readableContentTypes: [UTType] = [.plainText, .json, .commaSeparatedText]
    public let text: String
    public init(text: String) { self.text = text }
    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let value = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = value
    }
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
