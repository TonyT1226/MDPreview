import Foundation
import SwiftUI

/// 表格对齐方式
public enum MarkdownTableAlignment: Sendable, Hashable {
    case left
    case center
    case right
    case none
}

/// 任务列表项
public struct MarkdownTaskItem: Identifiable, Sendable, Hashable {
    public let id: String
    public var isChecked: Bool
    public var attributedText: AttributedString

    public init(id: String = UUID().uuidString, isChecked: Bool, attributedText: AttributedString) {
        self.id = id
        self.isChecked = isChecked
        self.attributedText = attributedText
    }
}

/// 有序列表项
public struct MarkdownOrderedListItem: Identifiable, Sendable, Hashable {
    public var id: String { "\(number)-\(text.description.hashValue)" }
    public let number: Int
    public let text: AttributedString

    public init(number: Int, text: AttributedString) {
        self.number = number
        self.text = text
    }
}

/// 纯原生渲染树的块级元素定义
public enum MarkdownBlock: Identifiable, Sendable, Hashable {
    case heading(id: String, level: Int, text: String, attributed: AttributedString)
    case paragraph(attributed: AttributedString)
    case codeBlock(id: String, language: String?, code: String, highlighted: AttributedString)
    case blockquote(blocks: [MarkdownBlock])
    case table(headers: [AttributedString], alignments: [MarkdownTableAlignment], rows: [[AttributedString]])
    case unorderedList(items: [AttributedString])
    case orderedList(items: [MarkdownOrderedListItem])
    case taskList(items: [MarkdownTaskItem])
    case thematicBreak
    case html(raw: String)

    public var id: String {
        switch self {
        case .heading(let id, _, _, _):
            return "heading-\(id)"
        case .paragraph(let attributed):
            return "p-\(attributed.characters.count)-\(attributed.description.hashValue)"
        case .codeBlock(let id, _, _, _):
            return "code-\(id)"
        case .blockquote(let blocks):
            return "quote-\(blocks.count)-\(blocks.first?.id ?? "")"
        case .table(let headers, _, _):
            return "table-\(headers.count)-\(headers.first?.description.hashValue ?? 0)"
        case .unorderedList(let items):
            return "ul-\(items.count)-\(items.first?.description.hashValue ?? 0)"
        case .orderedList(let items):
            return "ol-\(items.count)-\(items.first?.id ?? "")"
        case .taskList(let items):
            return "tasks-\(items.count)-\(items.first?.id ?? "")"
        case .thematicBreak:
            return "hr-\(UUID().uuidString)"
        case .html(let raw):
            return "html-\(raw.hashValue)"
        }
    }
}
