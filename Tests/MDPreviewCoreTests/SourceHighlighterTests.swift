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
}
