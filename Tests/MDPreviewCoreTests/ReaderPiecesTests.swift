import Testing
import AppKit
@testable import MDPreviewCore

@Suite("阅读区增量更新")
@MainActor
struct ReaderPiecesTests {

    private let renderer = ReaderRenderer(style: .default)

    /// 可比较的属性摘要（NSTextBlock 是引用，只比较数量和关键数值）。
    /// 先放进 NSTextStorage，让两边都经过同样的字体回退（中文字符换成苹方）
    private func summary(_ attributed: NSAttributedString) -> [String] {
        let s = attributed is NSTextStorage ? attributed : NSTextStorage(attributedString: attributed)
        var out: [String] = []
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { attrs, range, _ in
            let font = (attrs[.font] as? NSFont).map { "\($0.fontName) \($0.pointSize)" } ?? "-"
            let para = (attrs[.paragraphStyle] as? NSParagraphStyle).map {
                "\($0.paragraphSpacingBefore)/\($0.paragraphSpacing)/\($0.headIndent)/\($0.firstLineHeadIndent)/\($0.textBlocks.count)"
            } ?? "-"
            let task = (attrs[.mdTaskOrdinal] as? Int).map(String.init) ?? "-"
            out.append("\(range) \(font) \(para) \(task)")
        }
        return out
    }

    /// 从 `before` 增量更新到 `after`，结果必须与直接整篇渲染 `after` 一致
    @discardableResult
    private func check(_ before: String, _ after: String,
                       sourceLocation: SourceLocation = #_sourceLocation) -> ReaderPieces.Update {
        let storage = NSTextStorage()
        let pieces = ReaderPieces()
        pieces.update(to: MarkdownASTParser.parse(markdown: before).blocks, renderer: renderer, storage: storage)
        let parsed = MarkdownASTParser.parse(markdown: after)
        let update = pieces.update(to: parsed.blocks, renderer: renderer, storage: storage)
        let full = renderer.render(parsed.blocks)
        #expect(storage.string == full.text.string, sourceLocation: sourceLocation)
        #expect(summary(storage) == summary(full.text), sourceLocation: sourceLocation)
        #expect(pieces.headings.map(\.id) == full.headings.map(\.id), sourceLocation: sourceLocation)
        #expect(pieces.headings.map(\.location) == full.headings.map(\.location), sourceLocation: sourceLocation)
        return update
    }

    private let sample = """
    # 标题一

    第一段。

    - [ ] 待办
    - [x] 完成

    ## 标题二

    > 引用里的话

    ```swift
    let x = 1
    ```

    | A | B |
    | - | - |
    | 1 | 2 |

    最后一段。
    """

    @Test("改一个字只重渲染一块，结果与整篇渲染一致")
    func singleEdit() {
        let update = check(sample, sample.replacingOccurrences(of: "第一段", with: "第壹段"))
        #expect(update.renderedBlocks == 1)
    }

    @Test("开头、结尾、中间增删块")
    func insertAndDelete() {
        check(sample, "新开头\n\n" + sample)
        check(sample, "# 新标题\n\n" + sample)
        check(sample, sample + "\n\n追加一段")
        check(sample, sample + "\n\n## 追加标题")
        check(sample + "\n\n追加一段", sample)
        check(sample, sample.replacingOccurrences(of: "## 标题二\n\n", with: ""))
        check(sample, sample.replacingOccurrences(of: "最后一段。", with: ""))
        check(sample, sample.replacingOccurrences(of: "# 标题一\n\n", with: ""))
        check(sample, "")
        check("", sample)
        check(sample, "只剩一段")
    }

    @Test("上方插入一行：下方的块复用，复选框仍指向新行号")
    func taskLinesAfterInsert() throws {
        let storage = NSTextStorage()
        let pieces = ReaderPieces()
        pieces.update(to: MarkdownASTParser.parse(markdown: sample).blocks, renderer: renderer, storage: storage)
        let edited = "开头插一段\n\n" + sample
        let update = pieces.update(to: MarkdownASTParser.parse(markdown: edited).blocks,
                                   renderer: renderer, storage: storage)
        // 新段落 + 原来的第一块（它不再是文档开头，标题要加上边距）
        #expect(update.renderedBlocks == 2)

        var found: [(Int, Bool)] = []
        storage.enumerateAttribute(.mdTaskOrdinal, in: NSRange(location: 0, length: storage.length)) { v, r, _ in
            guard let ordinal = v as? Int, let task = pieces.task(at: r.location, ordinal: ordinal) else { return }
            found.append((task.line, task.checked))
        }
        #expect(found.count == 2)
        #expect(found[0] == (6, false))
        #expect(found[1] == (7, true))
        let lines = edited.components(separatedBy: "\n")
        #expect(lines[6] == "- [ ] 待办")
        #expect(lines[7] == "- [x] 完成")
    }

    @Test("标题新增后，后面标题的 id 更新而块本身复用")
    func headingIDsShift() {
        let edited = sample.replacingOccurrences(of: "第一段。", with: "第一段。\n\n### 插入的标题")
        let update = check(sample, edited)
        #expect(update.renderedBlocks == 1)
    }

    @Test("内容不变时不动 storage")
    func noChange() {
        let update = check(sample, sample)
        #expect(update.renderedBlocks == 0)
        #expect(update.replacedRange.length == 0)
    }

    @Test("只重渲染含图片的块（包括最后一块）")
    func rerenderImages() {
        for md in ["![a](x.png)\n\n正文\n\n> ![b](y.png)\n\n## 尾\n\n![c](z.png)", "![only](x.png)"] {
            let storage = NSTextStorage()
            let pieces = ReaderPieces()
            let parsed = MarkdownASTParser.parse(markdown: md)
            pieces.update(to: parsed.blocks, renderer: renderer, storage: storage)
            let count = pieces.rerender(where: \.containsImage, renderer: renderer, storage: storage)
            #expect(count == parsed.blocks.filter(\.containsImage).count)
            let full = renderer.render(parsed.blocks)
            #expect(storage.string == full.text.string)
            #expect(summary(storage) == summary(full.text))
            #expect(pieces.headings.map(\.location) == full.headings.map(\.location))
        }
    }

    @Test("随机编辑与整篇渲染一致")
    func randomEdits() {
        var rng = SystemRandomNumberGenerator()
        let fragments = ["# H\n\n", "段落\n\n", "- [ ] t\n", "- a\n", "> q\n\n", "```\nc\n```\n\n", "---\n\n", "1. o\n", "\n\n", "字"]
        var text = sample
        let storage = NSTextStorage()
        let pieces = ReaderPieces()
        pieces.update(to: MarkdownASTParser.parse(markdown: text).blocks, renderer: renderer, storage: storage)
        for _ in 0..<60 {
            let ns = text as NSString
            let loc = Int.random(in: 0...ns.length, using: &rng)
            if Bool.random(using: &rng), ns.length > 0 {
                let len = min(Int.random(in: 1...12, using: &rng), ns.length - loc)
                text = ns.replacingCharacters(in: NSRange(location: loc, length: len), with: "")
            } else {
                text = ns.replacingCharacters(in: NSRange(location: loc, length: 0),
                                              with: fragments.randomElement(using: &rng)!)
            }
            let parsed = MarkdownASTParser.parse(markdown: text)
            pieces.update(to: parsed.blocks, renderer: renderer, storage: storage)
            let full = renderer.render(parsed.blocks)
            #expect(storage.string == full.text.string)
            #expect(summary(storage) == summary(full.text))
            #expect(pieces.headings.map(\.location) == full.headings.map(\.location))
        }
    }
}
