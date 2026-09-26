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

// MARK: - 阅读区增量更新用

extension MarkdownBlock {
    /// 块内所有标题的 id，顺序与 `ReaderRenderer` 输出标题的顺序一致
    var renderedHeadingIDs: [String] {
        switch self {
        case .heading(let id, _, _, _):
            return [id]
        case .blockquote(_, let blocks):
            return blocks.flatMap(\.renderedHeadingIDs)
        case .unorderedList(_, let items), .orderedList(_, _, let items), .taskList(_, let items):
            return items.flatMap { $0.blocks.flatMap(\.renderedHeadingIDs) }
        default:
            return []
        }
    }

    /// 块内渲染成复选框的列表项，顺序与 `.mdTaskOrdinal` 一致
    var renderedTaskItems: [MarkdownListItem] {
        switch self {
        case .blockquote(_, let blocks):
            return blocks.flatMap(\.renderedTaskItems)
        case .taskList(_, let items):
            return items.flatMap { [$0] + $0.blocks.flatMap(\.renderedTaskItems) }
        case .unorderedList(_, let items), .orderedList(_, _, let items):
            return items.flatMap { $0.blocks.flatMap(\.renderedTaskItems) }
        default:
            return []
        }
    }

    /// 块内有图片（远程图片加载完要重渲染）
    var containsImage: Bool {
        switch self {
        case .image:
            return true
        case .blockquote(_, let blocks):
            return blocks.contains(where: \.containsImage)
        case .unorderedList(_, let items), .orderedList(_, _, let items), .taskList(_, let items):
            return items.contains { $0.blocks.contains(where: \.containsImage) }
        default:
            return false
        }
    }

    /// 渲染结果是否相同：忽略 id 和列表项的源行号（上方增删内容时它们会变，渲染出来的样子不变）
    func rendersSame(as other: MarkdownBlock) -> Bool {
        switch (self, other) {
        case let (.heading(_, l1, _, a1), .heading(_, l2, _, a2)):
            return l1 == l2 && a1 == a2
        case let (.paragraph(_, a1), .paragraph(_, a2)):
            return a1 == a2
        case let (.codeBlock(_, lang1, c1, h1), .codeBlock(_, lang2, c2, h2)):
            return lang1 == lang2 && c1 == c2 && h1 == h2
        case let (.blockquote(_, b1), .blockquote(_, b2)):
            return Self.rendersSame(b1, b2)
        case let (.table(_, h1, al1, r1), .table(_, h2, al2, r2)):
            return h1 == h2 && al1 == al2 && r1 == r2
        case let (.unorderedList(_, i1), .unorderedList(_, i2)),
             let (.taskList(_, i1), .taskList(_, i2)):
            return Self.rendersSame(i1, i2)
        case let (.orderedList(_, s1, i1), .orderedList(_, s2, i2)):
            return s1 == s2 && Self.rendersSame(i1, i2)
        case (.thematicBreak, .thematicBreak):
            return true
        case let (.image(_, s1, a1), .image(_, s2, a2)):
            return s1 == s2 && a1 == a2
        case let (.html(_, r1), .html(_, r2)):
            return r1 == r2
        default:
            return false
        }
    }

    private static func rendersSame(_ a: [MarkdownBlock], _ b: [MarkdownBlock]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.rendersSame(as: $1) }
    }

    private static func rendersSame(_ a: [MarkdownListItem], _ b: [MarkdownListItem]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy {
            $0.checkbox == $1.checkbox && ($0.sourceLine == nil) == ($1.sourceLine == nil)
                && rendersSame($0.blocks, $1.blocks)
        }
    }
}
