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
/// 与屏幕阅读区用同一个 `ReaderRenderer`，排进一个离屏的只读 `NSTextView`，由它按行分页。
/// 始终用浅色外观，暗色模式下打出来也是白底黑字。
@MainActor
public enum DocumentPrinter {

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

    private static func makeView(_ doc: PrintableDocument, printInfo: NSPrintInfo) -> NSView? {
        guard !doc.parsed.blocks.isEmpty else { return nil }
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isVerticallyCentered = false
        printInfo.isHorizontallyCentered = false

        let contentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        guard contentWidth > 0 else { return nil }
        return textView(for: doc, width: contentWidth, style: printStyle())
    }

    /// 打印用的排版：沿用字体与行距偏好，字号封顶 14，避免纸面过于稀疏
    private static func printStyle() -> ReaderStyle {
        var style = ReaderStyle.current()
        style.fontSize = min(style.fontSize, 14)
        return style
    }

    static func textView(for doc: PrintableDocument, width: CGFloat, style: ReaderStyle) -> NSTextView {
        let renderer = ReaderRenderer(style: style, baseURL: doc.baseURL, imageProvider: RemoteImageCache.shared)
        let rendered = renderer.render(doc.parsed.blocks)

        let tv = ReaderTextView.make()
        tv.appearance = NSAppearance(named: .aqua)
        tv.backgroundColor = .white
        tv.autoInsets = false
        tv.textContainerInset = .zero
        tv.frame = NSRect(x: 0, y: 0, width: width, height: 100)
        tv.textStorage?.setAttributedString(rendered.text)
        if let lm = tv.layoutManager, let tc = tv.textContainer {
            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc)
            tv.setFrameSize(NSSize(width: width, height: ceil(used.height) + 1))
        }
        return tv
    }
}
