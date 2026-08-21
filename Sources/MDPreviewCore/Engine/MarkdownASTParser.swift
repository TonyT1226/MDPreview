import SwiftUI
import Markdown

/// 解析结果模型
public struct ParsedDocument: Sendable {
    public let blocks: [MarkdownBlock]
    public let tocItems: [TOCItem]
    public let stats: DocumentStats

    public init(blocks: [MarkdownBlock] = [], tocItems: [TOCItem] = [], stats: DocumentStats = DocumentStats()) {
        self.blocks = blocks
        self.tocItems = tocItems
        self.stats = stats
    }
}

/// 基于 Apple swift-markdown 的纯原生 AST 解析引擎（包含极速缓存与预热）
public struct MarkdownASTParser: Sendable {
    
    // 线程安全内存缓存 (LRU / Hash-based)
    nonisolated(unsafe) private static let cache = NSCache<NSString, ParsedDocumentBox>()

    private final class ParsedDocumentBox: NSObject {
        let value: ParsedDocument
        init(_ value: ParsedDocument) {
            self.value = value
        }
    }

    /// 预热底层 CMark 与解析引擎
    public static func prewarm() {
        Task.detached(priority: .background) {
            _ = parse(markdown: "# Prewarm\n- Item")
        }
    }

    public static func parse(markdown: String) -> ParsedDocument {
        guard !markdown.isEmpty else {
            return ParsedDocument()
        }

        let cacheKey = NSString(string: "\(markdown.hashValue)-\(markdown.count)")
        if let cached = cache.object(forKey: cacheKey) {
            return cached.value
        }

        let document = Document(parsing: markdown, options: [.parseBlockDirectives, .parseSymbolLinks])
        var blocks: [MarkdownBlock] = []
        var rawTOC: [TOCItem] = []
        var headingIndex = 0

        for child in document.children {
            if let block = parseBlock(child, headingCounter: &headingIndex, tocList: &rawTOC) {
                blocks.append(block)
            }
        }

        let hierarchicalTOC = buildHierarchy(from: rawTOC)
        let stats = DocumentStats(text: markdown)

        let result = ParsedDocument(blocks: blocks, tocItems: hierarchicalTOC, stats: stats)
        cache.setObject(ParsedDocumentBox(result), forKey: cacheKey)
        return result
    }

    private static func parseBlock(
        _ markup: any Markup,
        headingCounter: inout Int,
        tocList: inout [TOCItem]
    ) -> MarkdownBlock? {
        switch markup {
        case let heading as Markdown.Heading:
            headingCounter += 1
            let titleText = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            let anchorId = "heading-\(headingCounter)-\(titleText.hashValue)"
            let attributed = AttributedStringBuilder.build(from: heading)
            
            let item = TOCItem(id: anchorId, level: heading.level, title: titleText)
            tocList.append(item)
            
            return .heading(id: anchorId, level: heading.level, text: titleText, attributed: attributed)

        case let paragraph as Markdown.Paragraph:
            let attributed = AttributedStringBuilder.build(from: paragraph)
            return .paragraph(attributed: attributed)

        case let codeBlock as Markdown.CodeBlock:
            let lang = codeBlock.language?.trimmingCharacters(in: .whitespaces)
            let rawCode = codeBlock.code
            let highlighted = NativeSyntaxHighlighter.highlight(code: rawCode, language: lang)
            let blockId = "\(lang ?? "code")-\(rawCode.hashValue)"
            return .codeBlock(id: blockId, language: lang, code: rawCode, highlighted: highlighted)

        case let blockQuote as Markdown.BlockQuote:
            var innerBlocks: [MarkdownBlock] = []
            for child in blockQuote.children {
                if let inner = parseBlock(child, headingCounter: &headingCounter, tocList: &tocList) {
                    innerBlocks.append(inner)
                }
            }
            return .blockquote(blocks: innerBlocks)

        case let table as Markdown.Table:
            var headers: [AttributedString] = []
            for cell in table.head.cells {
                headers.append(AttributedStringBuilder.build(from: cell))
            }

            var alignments: [MarkdownTableAlignment] = []
            for align in table.columnAlignments {
                switch align {
                case .left: alignments.append(.left)
                case .center: alignments.append(.center)
                case .right: alignments.append(.right)
                case .none: alignments.append(.none)
                }
            }

            var rows: [[AttributedString]] = []
            for row in table.body.rows {
                var rowCells: [AttributedString] = []
                for cell in row.cells {
                    rowCells.append(AttributedStringBuilder.build(from: cell))
                }
                rows.append(rowCells)
            }

            return .table(headers: headers, alignments: alignments, rows: rows)

        case let unorderedList as Markdown.UnorderedList:
            var isTaskList = false
            var taskItems: [MarkdownTaskItem] = []
            var plainItems: [AttributedString] = []

            for child in unorderedList.children {
                if let listItem = child as? Markdown.ListItem {
                    if let checkbox = listItem.checkbox {
                        isTaskList = true
                        let isChecked = checkbox == .checked
                        let attr = AttributedStringBuilder.build(from: listItem)
                        taskItems.append(MarkdownTaskItem(isChecked: isChecked, attributedText: attr))
                    } else {
                        plainItems.append(AttributedStringBuilder.build(from: listItem))
                    }
                }
            }

            if isTaskList && !taskItems.isEmpty {
                return .taskList(items: taskItems)
            } else {
                return .unorderedList(items: plainItems)
            }

        case let orderedList as Markdown.OrderedList:
            var items: [MarkdownOrderedListItem] = []
            let start = Int(orderedList.startIndex)
            for (idx, child) in orderedList.children.enumerated() {
                if let listItem = child as? Markdown.ListItem {
                    let attr = AttributedStringBuilder.build(from: listItem)
                    items.append(MarkdownOrderedListItem(number: start + idx, text: attr))
                }
            }
            return .orderedList(items: items)

        case _ as Markdown.ThematicBreak:
            return .thematicBreak

        case let htmlBlock as Markdown.HTMLBlock:
            return .html(raw: htmlBlock.rawHTML)

        default:
            return nil
        }
    }

    /// 将扁平的 TOC 列表组织为多级树状结构
    private static func buildHierarchy(from items: [TOCItem]) -> [TOCItem] {
        guard !items.isEmpty else { return [] }

        final class TOCItemRef {
            let id: String
            let level: Int
            let title: String
            var children: [TOCItemRef] = []

            init(_ item: TOCItem) {
                self.id = item.id
                self.level = item.level
                self.title = item.title
            }

            func toTOCItem() -> TOCItem {
                TOCItem(id: id, level: level, title: title, children: children.map { $0.toTOCItem() })
            }
        }

        var roots: [TOCItemRef] = []
        var stack: [TOCItemRef] = []

        for item in items {
            let node = TOCItemRef(item)
            while let last = stack.last, last.level >= node.level {
                _ = stack.popLast()
            }

            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            stack.append(node)
        }

        return roots.map { $0.toTOCItem() }
    }
}
