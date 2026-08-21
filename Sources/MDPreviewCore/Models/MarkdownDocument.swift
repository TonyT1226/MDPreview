import SwiftUI
import UniformTypeIdentifiers

public struct MarkdownDocument: FileDocument, @unchecked Sendable {
    public static var readableContentTypes: [UTType] {
        [
            UTType.plainText,
            UTType(importedAs: "net.daringfireball.markdown"),
            UTType(importedAs: "public.markdown"),
            UTType(importedAs: "public.text")
        ]
    }

    public var text: String

    public init(text: String = "") {
        self.text = text
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}
