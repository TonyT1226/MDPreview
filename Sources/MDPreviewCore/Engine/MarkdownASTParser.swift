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

/// 基于 Apple swift-markdown 的纯原生 AST 解析引擎（含极速缓存与预热）
public struct MarkdownASTParser: Sendable {

    // 线程安全内存缓存
    nonisolated(unsafe) private static let cache: NSCache<NSString, ParsedDocumentBox> = {
        let c = NSCache<NSString, ParsedDocumentBox>()
        c.countLimit = 32
        return c
    }()

    private final class ParsedDocumentBox: NSObject {
        let value: ParsedDocument
        init(_ value: ParsedDocument) { self.value = value }
    }

    /// 单调递增的稳定 id 生成器（同一文档按遍历序产出一致的 id 序列）
    private final class IDGen {
        private var n = 0
        func next(_ prefix: String = "b") -> String {
            defer { n += 1 }
            return "\(prefix)\(n)"
        }
    }

    /// 预热底层 cmark 与解析引擎
    public static func prewarm() {
        Task.detached(priority: .background) {
            _ = parse(markdown: "# Prewarm\n- Item")
        }
    }

    public static func parse(markdown: String) -> ParsedDocument {
        guard !markdown.isEmpty else { return ParsedDocument() }

        let cacheKey = NSString(string: "\(markdown.hashValue)-\(markdown.count)")
        if let cached = cache.object(forKey: cacheKey) {
            return cached.value
        }

        let document = Document(parsing: markdown, options: [.parseBlockDirectives, .parseSymbolLinks])
        let idGen = IDGen()
        var blocks: [MarkdownBlock] = []
        var rawTOC: [TOCItem] = []
        var headingIndex = 0

        for child in document.children {
            if let block = parseBlock(child, idGen: idGen, headingCounter: &headingIndex, tocList: &rawTOC, collectTOC: true) {
                blocks.append(block)
            }
        }

        let result = ParsedDocument(
            blocks: blocks,
            tocItems: buildHierarchy(from: rawTOC),
            stats: DocumentStats(text: markdown)
        )
        cache.setObject(ParsedDocumentBox(result), forKey: cacheKey)
        return result
    }

    // MARK: - Block

    private static func parseBlock(
        _ markup: any Markup,
        idGen: IDGen,
        headingCounter: inout Int,
        tocList: inout [TOCItem],
        collectTOC: Bool
    ) -> MarkdownBlock? {
        switch markup {
        case let heading as Markdown.Heading:
            headingCounter += 1
            let titleText = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            let anchorId = "heading-\(headingCounter)"
            let attributed = AttributedStringBuilder.build(from: heading, baseFont: headingBaseFont(level: heading.level))
            if collectTOC {
                tocList.append(TOCItem(id: anchorId, level: heading.level, title: titleText))
            }
            return .heading(id: anchorId, level: heading.level, text: titleText, attributed: attributed)

        case let paragraph as Markdown.Paragraph:
            // 仅含图片的段落 → 独立图片块
            if let imageBlock = imageOnlyBlock(paragraph, idGen: idGen) {
                return imageBlock
            }
            return .paragraph(id: idGen.next(), attributed: AttributedStringBuilder.build(from: paragraph))

        case let codeBlock as Markdown.CodeBlock:
            let lang = codeBlock.language?.trimmingCharacters(in: .whitespaces)
            let rawCode = codeBlock.code
            let highlighted = NativeSyntaxHighlighter.highlight(code: rawCode, language: lang)
            return .codeBlock(id: idGen.next(), language: lang, code: rawCode, highlighted: highlighted)

        case let blockQuote as Markdown.BlockQuote:
            let id = idGen.next()
            var inner: [MarkdownBlock] = []
            for child in blockQuote.children {
                if let b = parseBlock(child, idGen: idGen, headingCounter: &headingCounter, tocList: &tocList, collectTOC: false) {
                    inner.append(b)
                }
            }
            return .blockquote(id: id, blocks: inner)

        case let table as Markdown.Table:
            let headers = Array(table.head.cells.map { AttributedStringBuilder.build(from: $0) })
            let alignments: [MarkdownTableAlignment] = table.columnAlignments.map {
                switch $0 {
                case .left: return .left
                case .center: return .center
                case .right: return .right
                case .none: return .none
                }
            }
            let rows: [[AttributedString]] = table.body.rows.map { row in
                Array(row.cells.map { AttributedStringBuilder.build(from: $0) })
            }
            return .table(id: idGen.next(), headers: headers, alignments: alignments, rows: rows)

        case let unordered as Markdown.UnorderedList:
            let id = idGen.next()
            var items: [MarkdownListItem] = []
            var isTask = false
            for case let listItem as Markdown.ListItem in unordered.children {
                let item = parseListItem(listItem, idGen: idGen, headingCounter: &headingCounter, tocList: &tocList)
                if item.checkbox != nil { isTask = true }
                items.append(item)
            }
            return isTask ? .taskList(id: id, items: items) : .unorderedList(id: id, items: items)

        case let ordered as Markdown.OrderedList:
            let id = idGen.next()
            var items: [MarkdownListItem] = []
            for case let listItem as Markdown.ListItem in ordered.children {
                items.append(parseListItem(listItem, idGen: idGen, headingCounter: &headingCounter, tocList: &tocList))
            }
            return .orderedList(id: id, start: Int(ordered.startIndex), items: items)

        case _ as Markdown.ThematicBreak:
            return .thematicBreak(id: idGen.next())

        case let htmlBlock as Markdown.HTMLBlock:
            return .html(id: idGen.next(), raw: htmlBlock.rawHTML)

        default:
            return nil
        }
    }

    private static func parseListItem(
        _ listItem: Markdown.ListItem,
        idGen: IDGen,
        headingCounter: inout Int,
        tocList: inout [TOCItem]
    ) -> MarkdownListItem {
        let id = idGen.next()
        let checkbox: Bool? = listItem.checkbox.map { $0 == .checked }
        let sourceLine = listItem.range.map { $0.lowerBound.line - 1 } // 转 0 基

        var blocks: [MarkdownBlock] = []
        for child in listItem.children {
            if let b = parseBlock(child, idGen: idGen, headingCounter: &headingCounter, tocList: &tocList, collectTOC: false) {
                blocks.append(b)
            }
        }
        return MarkdownListItem(id: id, checkbox: checkbox, sourceLine: sourceLine, blocks: blocks)
    }

    /// 段落若仅由图片（及空白）构成，返回图片块
    private static func imageOnlyBlock(_ paragraph: Markdown.Paragraph, idGen: IDGen) -> MarkdownBlock? {
        var image: Markdown.Image?
        for child in paragraph.inlineChildren {
            switch child {
            case let img as Markdown.Image:
                if image != nil { return nil } // 多图暂按普通段落处理（占位）
                image = img
            case let text as Markdown.Text where text.string.trimmingCharacters(in: .whitespaces).isEmpty:
                continue
            case _ as Markdown.SoftBreak, _ as Markdown.LineBreak:
                continue
            default:
                return nil
            }
        }
        guard let image else { return nil }
        let alt = image.plainText.isEmpty ? (image.title ?? "") : image.plainText
        return .image(id: idGen.next(), source: image.source, alt: alt)
    }

    private static func headingBaseFont(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 26, weight: .bold)
        case 2: return .system(size: 21, weight: .semibold)
        case 3: return .system(size: 17, weight: .medium)
        case 4: return .system(size: 15, weight: .medium)
        case 5: return .system(size: 14, weight: .regular)
        default: return .system(size: 13, weight: .regular)
        }
    }

    // MARK: - TOC 层级

    private static func buildHierarchy(from items: [TOCItem]) -> [TOCItem] {
        guard !items.isEmpty else { return [] }

        final class Ref {
            let id: String
            let level: Int
            let title: String
            var children: [Ref] = []
            init(_ item: TOCItem) {
                self.id = item.id
                self.level = item.level
                self.title = item.title
            }
            func toItem() -> TOCItem {
                TOCItem(id: id, level: level, title: title, children: children.map { $0.toItem() })
            }
        }

        var roots: [Ref] = []
        var stack: [Ref] = []
        for item in items {
            let node = Ref(item)
            while let last = stack.last, last.level >= node.level { _ = stack.popLast() }
            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }
            stack.append(node)
        }
        return roots.map { $0.toItem() }
    }
}
