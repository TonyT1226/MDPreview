import SwiftUI
import UniformTypeIdentifiers

public struct MarkdownDocument: FileDocument, @unchecked Sendable {
    public static var readableContentTypes: [UTType] {
        var types: [UTType] = [
            UTType(importedAs: "net.daringfireball.markdown"),
            UTType(importedAs: "public.markdown"),
            UTType.plainText,
            UTType.text
        ]
        if let mdExt = UTType(filenameExtension: "md") {
            types.append(mdExt)
        }
        if let markdownExt = UTType(filenameExtension: "markdown") {
            types.append(markdownExt)
        }
        return types
    }

    public static var writableContentTypes: [UTType] {
        readableContentTypes
    }

    public var text: String

    public init(text: String = "") {
        self.text = text
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let string = String(data: data, encoding: .utf8) {
            self.text = string
        } else if let string = String(data: data, encoding: .utf16) {
            self.text = string
        } else if let string = String(data: data, encoding: .isoLatin1) {
            self.text = string
        } else {
            self.text = ""
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}
