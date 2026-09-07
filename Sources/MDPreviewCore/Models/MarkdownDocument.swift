import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// 与 App Info.plist 的 UTImportedTypeDeclarations 声明保持一致
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

public struct MarkdownDocument: FileDocument, @unchecked Sendable {
    public static let readableContentTypes: [UTType] = [.markdown, .plainText]
    public static let writableContentTypes: [UTType] = [.markdown, .plainText]

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
