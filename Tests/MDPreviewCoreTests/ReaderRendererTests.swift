import Testing
import AppKit
@testable import MDPreviewCore

@Suite("阅读区渲染")
@MainActor
struct ReaderRendererTests {

    private func render(_ md: String, style: ReaderStyle = .default) -> RenderedDocument {
        let parsed = MarkdownASTParser.parse(markdown: md)
        return ReaderRenderer(style: style).render(parsed.blocks)
    }

    private func paragraphStyle(_ doc: RenderedDocument, containing needle: String) -> NSParagraphStyle? {
        let range = (doc.text.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return doc.text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
    }

    @Test("整篇文档是一段连续文本，标题位置与 TOC id 对应")
    func headingsRecorded() {
        let md = "# 一\n\n正文\n\n## 二\n\n更多正文\n"
        let parsed = MarkdownASTParser.parse(markdown: md)
        let doc = ReaderRenderer(style: .default).render(parsed.blocks)
        #expect(doc.headings.map(\.id) == ["heading-1", "heading-2"])
        #expect(doc.headings.map(\.id) == parsed.tocItems.flatMap { [$0.id] + $0.children.map(\.id) })
        let s = doc.text.string as NSString
        #expect(s.substring(with: NSRange(location: doc.headings[1].location, length: 1)) == "二")
        #expect(doc.text.attribute(.mdHeadingID, at: doc.headings[0].location, effectiveRange: nil) as? String == "heading-1")
        #expect(!doc.text.string.hasSuffix("\n"))
    }

    @Test("任务项带源行号与勾选状态")
    func taskAttributes() {
        let doc = render("前言\n\n- [ ] 待办\n- [x] 完成\n")
        var found: [(Int, Bool)] = []
        doc.text.enumerateAttribute(.mdTaskSourceLine, in: NSRange(location: 0, length: doc.text.length)) { v, range, _ in
            guard let line = v as? Int else { return }
            let checked = doc.text.attribute(.mdTaskChecked, at: range.location, effectiveRange: nil) as? Bool ?? false
            found.append((line, checked))
        }
        #expect(found.count == 2)
        #expect(found[0] == (2, false))
        #expect(found[1] == (3, true))
    }

    @Test("代码块放进带底色的 NSTextBlock，使用等宽字体")
    func codeBlock() {
        let doc = render("```swift\nlet answer = 42\n```\n")
        let para = paragraphStyle(doc, containing: "answer")
        #expect(para?.textBlocks.count == 1)
        #expect(para?.textBlocks.first?.backgroundColor != nil)
        let range = (doc.text.string as NSString).range(of: "answer")
        let font = doc.text.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        #expect(font?.isFixedPitch == true)
    }

    @Test("表格用 NSTextTable，每个单元格一个段落")
    func table() {
        let doc = render("| A | B |\n| - | -: |\n| 1 | 2 |\n")
        let cell = paragraphStyle(doc, containing: "2")?.textBlocks.last as? NSTextTableBlock
        #expect(cell != nil)
        #expect(cell?.table.numberOfColumns == 2)
        #expect(cell?.startingRow == 1)
        #expect(cell?.startingColumn == 1)
        #expect(paragraphStyle(doc, containing: "2")?.alignment == .right)
    }

    @Test("引用内嵌套代码块：textBlocks 由外到内叠加")
    func nestedBlocks() {
        let doc = render("> 引用\n>\n> ```\n> code\n> ```\n")
        #expect(paragraphStyle(doc, containing: "引用")?.textBlocks.count == 1)
        #expect(paragraphStyle(doc, containing: "code")?.textBlocks.count == 2)
    }

    @Test("行内：强调、代码、链接")
    func inlineStyles() {
        let doc = render("普通 **粗** *斜* `code` [链接](https://example.com)\n")
        let s = doc.text.string as NSString
        let bold = doc.text.attribute(.font, at: s.range(of: "粗").location, effectiveRange: nil) as? NSFont
        #expect(bold?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        let code = doc.text.attribute(.font, at: s.range(of: "code").location, effectiveRange: nil) as? NSFont
        #expect(code?.isFixedPitch == true)
        let link = doc.text.attribute(.link, at: s.range(of: "链接").location, effectiveRange: nil) as? URL
        #expect(link?.host == "example.com")
    }

    @Test("字号偏好影响正文字体")
    func fontSizeFollowsStyle() {
        let big = ReaderStyle(fontSize: 20, lineHeight: 1.5, contentWidth: 800, fontFamily: .serif)
        let doc = render("正文\n", style: big)
        let font = doc.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 20)
        #expect((doc.text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.lineHeightMultiple == 1.5)
    }

    @Test("有序列表从指定序号开始，嵌套列表缩进更深")
    func lists() {
        let doc = render("3. 三\n4. 四\n   - 子项\n")
        #expect(doc.text.string.contains("3.\t三"))
        #expect(doc.text.string.contains("4.\t四"))
        let outer = paragraphStyle(doc, containing: "三")!
        let inner = paragraphStyle(doc, containing: "子项")!
        #expect(inner.headIndent > outer.headIndent)
    }

    @Test("ReaderStyle 数值被限制在合法范围")
    func styleClamping() {
        let s = ReaderStyle(fontSize: 100, lineHeight: 0.1, contentWidth: 10, fontFamily: .system)
        #expect(s.fontSize == ReaderStyle.fontSizeRange.upperBound)
        #expect(s.lineHeight == ReaderStyle.lineHeightRange.lowerBound)
        #expect(s.contentWidth == ReaderStyle.contentWidthRange.lowerBound)
    }

    @Test("GitHub 风格锚点 slug")
    func slug() {
        #expect(ReaderTextRepresentable.Coordinator.slug("Hello, World!") == "hello-world")
        #expect(ReaderTextRepresentable.Coordinator.slug("安装 步骤") == "安装-步骤")
    }
}
