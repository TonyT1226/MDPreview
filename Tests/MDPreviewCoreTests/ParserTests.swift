import Testing
import Foundation
@testable import MDPreviewCore

@Suite("Markdown AST 解析")
struct ParserTests {

    @Test("基础块类型都能解析")
    func basicBlocks() {
        let md = """
        # 标题一

        普通段落，包含 **加粗** 与 `行内代码`。

        ## 标题二

        - 项 1
        - 项 2

        1. 有序 1
        2. 有序 2

        - [ ] 未完成
        - [x] 已完成

        > 引用

        ```swift
        let x = 1
        ```

        | A | B |
        | :- | -: |
        | 1 | 2 |

        ---
        """
        let doc = MarkdownASTParser.parse(markdown: md)

        #expect(doc.blocks.contains { if case .heading = $0 { return true } else { return false } })
        #expect(doc.blocks.contains { if case .codeBlock = $0 { return true } else { return false } })
        #expect(doc.blocks.contains { if case .table = $0 { return true } else { return false } })
        #expect(doc.blocks.contains { if case .blockquote = $0 { return true } else { return false } })
        #expect(doc.blocks.contains { if case .taskList = $0 { return true } else { return false } })
        #expect(doc.blocks.contains { if case .thematicBreak = $0 { return true } else { return false } })
    }

    @Test("block id 稳定：多次解析同一文本 id 序列一致")
    func stableBlockIDs() {
        let md = "# A\n\n---\n\n段落\n\n---\n"
        let first = MarkdownASTParser.parse(markdown: md).blocks.map(\.id)
        let second = MarkdownASTParser.parse(markdown: md + " ").blocks.map(\.id) // 触发不同缓存键
        #expect(first == second)
        #expect(Set(first).count == first.count) // 无重复
    }

    @Test("TOC 层级构建正确")
    func tocHierarchy() {
        let md = "# 一\n\n## 1.1\n\n### 1.1.1\n\n## 1.2\n\n# 二\n"
        let toc = MarkdownASTParser.parse(markdown: md).tocItems
        #expect(toc.count == 2)
        #expect(toc.first?.children.count == 2)
        #expect(toc.first?.children.first?.children.count == 1)
    }

    @Test("引用块内的标题不进入 TOC")
    func blockquoteHeadingNotInTOC() {
        let md = "# 真标题\n\n> ## 引用里的标题\n"
        let parsed = MarkdownASTParser.parse(markdown: md)
        #expect(parsed.tocItems.count == 1)
        #expect(parsed.tocItems.first?.title == "真标题")
    }

    @Test("嵌套无序列表被保留为子块而非拍平")
    func nestedList() {
        let md = """
        - 顶层
          - 子项 A
          - 子项 B
        - 顶层 2
        """
        let parsed = MarkdownASTParser.parse(markdown: md)
        guard case let .unorderedList(_, items)? = parsed.blocks.first else {
            Issue.record("首块不是无序列表")
            return
        }
        #expect(items.count == 2)
        // 第一个顶层项内应含一个嵌套列表块
        #expect(items.first?.blocks.contains { if case .unorderedList = $0 { return true } else { return false } } == true)
    }
}

@Suite("文档统计")
struct StatsTests {
    @Test("中文按字数统计")
    func cjkWordCount() {
        let stats = DocumentStats(text: "这是一段中文文本没有空格")
        #expect(stats.wordCount == 12)
    }

    @Test("英文按词数统计")
    func latinWordCount() {
        let stats = DocumentStats(text: "the quick brown fox")
        #expect(stats.wordCount == 4)
    }
}

@Suite("行内样式")
struct InlineTests {
    @Test("==高亮== 生效且不误伤 a == b")
    func highlightSyntax() {
        let attr = AttributedStringBuilder.parseHighlightSyntax(in: "前 ==重点== 后，判断 a == b 成立")
        let plain = String(attr.characters)
        #expect(plain == "前 重点 后，判断 a == b 成立")
        let hasHighlight = attr.runs.contains { $0.backgroundColor != nil }
        #expect(hasHighlight)
    }
}
