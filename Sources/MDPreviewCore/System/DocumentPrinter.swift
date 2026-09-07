import SwiftUI
import AppKit

/// 传给打印 / 导出的文档快照（经 `FocusedValue` 从当前窗口取到）
public struct PrintableDocument: Sendable {
    public var parsed: ParsedDocument
    public var title: String
    public var baseURL: URL?

    public init(parsed: ParsedDocument, title: String, baseURL: URL?) {
        self.parsed = parsed
        self.title = title
        self.baseURL = baseURL
    }
}

/// 把阅读视图渲染成矢量 PDF —— 打印与「导出为 PDF…」共用一条 `NSPrintOperation` 路径。
///
/// 分页在**块边界**上断（逐块量高度后贪心装页），不会把代码块 / 表格拦腰截断。
/// 单个块高于一页时任其溢出（少见）。
@MainActor
public enum DocumentPrinter {

    private static let blockSpacing: CGFloat = 14

    public static func runPrintPanel(_ doc: PrintableDocument) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        guard let view = makeView(doc, printInfo: info) else { NSSound.beep(); return }
        let op = NSPrintOperation(view: view, printInfo: info)
        op.jobTitle = doc.title
        op.run()
    }

    public static func exportPDF(_ doc: PrintableDocument) {
        let panel = NSSavePanel()
        panel.title = L.exportPDFPanelTitle
        panel.nameFieldStringValue = L.exportPDFDefaultName(title: doc.title)
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL.rawValue] = url
        guard let view = makeView(doc, printInfo: info) else { NSSound.beep(); return }

        let op = NSPrintOperation(view: view, printInfo: info)
        op.jobTitle = doc.title
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        op.run()
    }

    // MARK: -

    private static func makeView(_ doc: PrintableDocument, printInfo: NSPrintInfo) -> PrintableDocumentView? {
        guard !doc.parsed.blocks.isEmpty else { return nil }

        let contentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let contentHeight = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin
        guard contentWidth > 0, contentHeight > 0 else { return nil }

        let context = MarkdownRenderContext(baseURL: doc.baseURL)

        return PrintableDocumentView(blocks: doc.parsed.blocks,
                                     context: context,
                                     contentSize: NSSize(width: contentWidth, height: contentHeight),
                                     blockSpacing: blockSpacing)
    }

    #if DEBUG
    /// 测试用：按给定页面尺寸构建分页视图
    static func paginatedViewForTesting(_ doc: PrintableDocument, pageSize: NSSize) -> PrintableDocumentView {
        let context = MarkdownRenderContext(baseURL: doc.baseURL)
        return PrintableDocumentView(blocks: doc.parsed.blocks,
                                     context: context,
                                     contentSize: pageSize,
                                     blockSpacing: blockSpacing)
    }
    #endif
}

/// 承载逐块子视图并按块边界分页的打印视图
final class PrintableDocumentView: NSView {

    private let pageContentSize: NSSize
    private var pageRects: [NSRect] = []

    /// 分页出来的页数（供测试）
    var pageCount: Int { max(1, pageRects.count) }

    init(blocks: [MarkdownBlock],
         context: MarkdownRenderContext,
         contentSize: NSSize,
         blockSpacing: CGFloat) {
        self.pageContentSize = contentSize
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: contentSize.width, height: contentSize.height)))

        let light = NSAppearance(named: .aqua)
        var y: CGFloat = 0
        var pageStartY: CGFloat = 0
        var pageBreaks: [CGFloat] = [0]

        for block in blocks {
            let host = NSHostingView(rootView:
                MarkdownBlockDispatcher(block: block)
                    .environment(\.markdownContext, context)
                    .frame(width: contentSize.width, alignment: .leading)
            )
            host.appearance = light
            let h = host.fittingSize.height
            host.frame = NSRect(x: 0, y: y, width: contentSize.width, height: h)

            // 这一块放不下当前页 → 起新页（当前页非空时）
            if y - pageStartY + h > contentSize.height, y > pageStartY {
                pageStartY = y
                pageBreaks.append(y)
            }
            addSubview(host)
            y += h + blockSpacing
        }

        let totalHeight = max(y, contentSize.height)
        setFrameSize(NSSize(width: contentSize.width, height: totalHeight))

        pageRects = pageBreaks.enumerated().map { idx, top in
            NSRect(x: 0, y: top, width: contentSize.width, height: contentSize.height)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: max(1, pageRects.count))
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        guard pageRects.indices.contains(page - 1) else {
            return NSRect(origin: .zero, size: pageContentSize)
        }
        return pageRects[page - 1]
    }
}
