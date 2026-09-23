import AppKit

/// Quick Look 扩展（预览 / 缩略图）用的渲染入口。扩展进程里没有 SwiftUI 场景，直接拿 AppKit 视图。
@MainActor
public enum QuickLookSupport {

    /// 读文件文本（与 `MarkdownDocument` 同样的编码回退）
    public nonisolated static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    /// 空格预览：可滚动、可选择的阅读视图（与 App 阅读区同一套排版，使用用户的字体偏好默认值）
    public static func previewView(markdown: String, baseURL: URL?) -> NSView {
        let parsed = MarkdownASTParser.parse(markdown: markdown)
        let style = ReaderStyle(fontSize: 14, lineHeight: ReaderStyle.default.lineHeight,
                                contentWidth: 760, fontFamily: .system)
        // 扩展在沙盒里没有网络权限，远程图片直接显示占位符
        let rendered = ReaderRenderer(style: style, baseURL: baseURL).render(parsed.blocks)

        let textView = ReaderTextView.make()
        textView.contentWidth = style.contentWidth
        textView.textStorage?.setAttributedString(rendered.text)
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView
        return scrollView
    }

    /// 缩略图：把文档开头排成一页「纸」，按 `size` 等比画进当前图形上下文。
    /// 返回的闭包可在任意线程调用（只用到已排好的文本和私有的 TextKit 栈）。
    public static func thumbnailDrawing(markdown: String, size: CGSize) -> @Sendable () -> Bool {
        let parsed = MarkdownASTParser.parse(markdown: markdown)
        let style = ReaderStyle(fontSize: 13, lineHeight: 1.3, contentWidth: 600, fontFamily: .system)
        let text = ReaderRenderer(style: style).render(Array(parsed.blocks.prefix(40))).text
        let payload = UncheckedBox(text)

        return {
            // 固定「纸面」宽度排版，再整体缩放到缩略图尺寸
            let pageWidth: CGFloat = 600
            let pageHeight = pageWidth * size.height / max(size.width, 1)
            let margin: CGFloat = 36
            let scale = size.width / pageWidth

            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let light = NSAppearance(named: .aqua)!
            var drew = false
            light.performAsCurrentDrawingAppearance {
                ctx.saveGState()
                NSColor.white.setFill()
                NSRect(origin: .zero, size: size).fill()

                // 翻转坐标：TextKit 按自上而下绘制
                ctx.translateBy(x: 0, y: size.height)
                ctx.scaleBy(x: scale, y: -scale)
                let flipped = NSGraphicsContext(cgContext: ctx, flipped: true)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = flipped

                let storage = NSTextStorage(attributedString: payload.value)
                let layout = NSLayoutManager()
                let container = NSTextContainer(size: NSSize(width: pageWidth - margin * 2,
                                                             height: pageHeight - margin * 2))
                container.lineFragmentPadding = 0
                layout.addTextContainer(container)
                storage.addLayoutManager(layout)
                let glyphs = layout.glyphRange(for: container)
                let origin = NSPoint(x: margin, y: margin)
                layout.drawBackground(forGlyphRange: glyphs, at: origin)
                layout.drawGlyphs(forGlyphRange: glyphs, at: origin)

                NSGraphicsContext.restoreGraphicsState()
                ctx.restoreGState()
                drew = true
            }
            return drew
        }
    }
}

/// NSAttributedString 不是 Sendable；这里只读不改，跨线程传递是安全的
private final class UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
