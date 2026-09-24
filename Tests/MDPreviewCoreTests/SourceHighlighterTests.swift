import Testing
import Foundation
@testable import MDPreviewCore

@Suite("Markdown 源码着色扫描器")
struct SourceHighlighterTests {

    private func kinds(_ text: String) -> Set<MarkdownSourceHighlighter.Kind> {
        Set(MarkdownSourceHighlighter.tokens(in: text).map(\.kind))
    }

    @Test("标题前缀识别为 heading")
    func heading() {
        let toks = MarkdownSourceHighlighter.tokens(in: "## 小标题\n正文")
        #expect(toks.contains { $0.kind == .heading })
        // 非标题的 '#'
        #expect(!MarkdownSourceHighlighter.tokens(in: "a # b").contains { $0.kind == .heading })
    }

    @Test("加粗 / 斜体 / 删除线 / 行内代码")
    func inlineStyles() {
        let k = kinds("这是 **粗** 和 *斜* 和 ~~删~~ 和 `代码`")
        #expect(k.contains(.strong))
        #expect(k.contains(.emphasis))
        #expect(k.contains(.strikethrough))
        #expect(k.contains(.inlineCode))
    }

    @Test("围栏代码块整段标记为 codeFence")
    func fence() {
        let md = """
        前言

        ```swift
        let x = 1
        let y = 2
        ```

        后记
        """
        let fenceTokens = MarkdownSourceHighlighter.tokens(in: md).filter { $0.kind == .codeFence }
        // 两行 ``` + 两行代码 = 4 个 codeFence token
        #expect(fenceTokens.count == 4)
        // 围栏外的普通文本不应被标记
        #expect(!MarkdownSourceHighlighter.tokens(in: md).contains {
            $0.kind == .codeFence && (md as NSString).substring(with: $0.range).contains("前言")
        })
    }

    @Test("列表标记与引用前缀")
    func listAndQuote() {
        #expect(kinds("- 项目").contains(.listMarker))
        #expect(kinds("1. 项目").contains(.listMarker))
        #expect(kinds("> 引用").contains(.blockquote))
        // 'a - b' 不是列表
        #expect(!kinds("a - b").contains(.listMarker))
    }

    @Test("链接与分隔线")
    func linkAndRule() {
        #expect(kinds("见 [文档](https://example.com)").contains(.link))
        #expect(kinds("---").contains(.thematicBreak))
        #expect(kinds("***").contains(.thematicBreak))
    }

    @Test("token 的 range 落在源码字符串内")
    func rangesInBounds() {
        let text = "# 标题\n\n**粗** 与 `码`\n\n> 引用\n"
        let ns = text as NSString
        for token in MarkdownSourceHighlighter.tokens(in: text) {
            #expect(token.range.location >= 0)
            #expect(token.range.location + token.range.length <= ns.length)
        }
    }

    @Test("**粗** 只算加粗，不再被斜体规则吃掉；*斜* 仍是斜体")
    func boldIsNotItalic() {
        let bold = MarkdownSourceHighlighter.tokens(in: "正文 **加粗** 结束")
        #expect(bold.map(\.kind) == [.strong])
        let italic = MarkdownSourceHighlighter.tokens(in: "正文 *斜体* 结束")
        #expect(italic.map(\.kind) == [.emphasis])
        let both = MarkdownSourceHighlighter.tokens(in: "**粗** 和 *斜*")
        #expect(both.map(\.kind) == [.strong, .emphasis])
    }

    @Test("行内代码里的标记不着色")
    func noStylesInsideInlineCode() {
        let toks = MarkdownSourceHighlighter.tokens(in: "看 `a **b** c` 这里")
        #expect(toks.map(\.kind) == [.inlineCode])
    }

    @Test("token 按起点排序，按区间取出的正好是这一行的")
    func sortedAndSliced() {
        let md = "# 标题\n**粗** `c`\n- 项 *斜*\n"
        let toks = MarkdownSourceHighlighter.tokens(in: md)
        #expect(toks.map(\.range.location) == toks.map(\.range.location).sorted())
        let ns = md as NSString
        let line2 = ns.lineRange(for: NSRange(location: ns.range(of: "**").location, length: 0))
        let slice = MarkdownSourceHighlighter.tokens(toks, startingIn: line2)
        #expect(slice.map(\.kind) == [.strong, .inlineCode])
    }
}
