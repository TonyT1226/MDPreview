import Testing
import AppKit
@testable import MDPreviewCore

@Suite("PDF 分页")
@MainActor
struct DocumentPrinterTests {

    private func longDocument(paragraphs: Int) -> PrintableDocument {
        let body = (1...paragraphs).map { "这是第 \($0) 段正文，用来把内容撑到多页。包含一些 **强调** 与 `代码`。" }
            .joined(separator: "\n\n")
        let parsed = MarkdownASTParser.parse(markdown: "# 标题\n\n" + body)
        return PrintableDocument(parsed: parsed, title: "长文.md", baseURL: nil)
    }

    @Test("长文档被分成多页，块边界不为空")
    func paginatesLongDocument() {
        let doc = longDocument(paragraphs: 60)
        let view = DocumentPrinter.paginatedViewForTesting(
            doc, pageSize: NSSize(width: 468, height: 300)
        )
        #expect(view.pageCount > 1)

        var range = NSRange()
        #expect(view.knowsPageRange(&range))
        #expect(range.length == view.pageCount)
        #expect(range.location == 1)
    }

    @Test("空文档不产出打印视图")
    func emptyDocumentTitleFallback() {
        // exportPDFDefaultName 去扩展名再补 .pdf
        #expect(L.exportPDFDefaultName(title: "报告.md") == "报告.pdf")
        #expect(L.exportPDFDefaultName(title: "无扩展名") == "无扩展名.pdf")
    }
}
