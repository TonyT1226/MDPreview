import Foundation
import SwiftUI

/// 表格对齐方式
public enum MarkdownTableAlignment: Sendable, Hashable {
    case left
    case center
    case right
    case none
}

/// 列表项（可持有任意子块：段落、嵌套列表、代码块……）
public struct MarkdownListItem: Identifiable, Sendable, Hashable {
    public let id: String
    /// 任务列表复选框状态；非任务项为 nil
    public var checkbox: Bool?
    /// 复选框在源文档中的行号（0 基），用于交互回写
    public var sourceLine: Int?
    public var blocks: [MarkdownBlock]

    public init(id: String, checkbox: Bool? = nil, sourceLine: Int? = nil, blocks: [MarkdownBlock]) {
        self.id = id
        self.checkbox = checkbox
        self.sourceLine = sourceLine
        self.blocks = blocks
    }
}

/// 纯原生渲染树的块级元素定义
public enum MarkdownBlock: Identifiable, Sendable, Hashable {
    case heading(id: String, level: Int, text: String, attributed: AttributedString)
    case paragraph(id: String, attributed: AttributedString)
    case codeBlock(id: String, language: String?, code: String, highlighted: AttributedString)
    case blockquote(id: String, blocks: [MarkdownBlock])
    case table(id: String, headers: [AttributedString], alignments: [MarkdownTableAlignment], rows: [[AttributedString]])
    case unorderedList(id: String, items: [MarkdownListItem])
    case orderedList(id: String, start: Int, items: [MarkdownListItem])
    case taskList(id: String, items: [MarkdownListItem])
    case thematicBreak(id: String)
    case image(id: String, source: String?, alt: String)
    case html(id: String, raw: String)

    public var id: String {
        switch self {
        case .heading(let id, _, _, _),
             .paragraph(let id, _),
             .codeBlock(let id, _, _, _),
             .blockquote(let id, _),
             .table(let id, _, _, _),
             .unorderedList(let id, _),
             .orderedList(let id, _, _),
             .taskList(let id, _),
             .thematicBreak(let id),
             .image(let id, _, _),
             .html(let id, _):
            return id
        }
    }
}
