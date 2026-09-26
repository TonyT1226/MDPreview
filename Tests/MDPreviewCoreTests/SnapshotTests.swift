import Testing
import AppKit
import SwiftUI
@testable import MDPreviewCore

/// 目视检查用：设置环境变量 MDP_SNAPSHOT_DIR 时，把示例文档的阅读区渲染成 PNG（浅色 / 深色）。
/// 平时不设置就直接跳过。
@Suite("阅读区快照（手动）")
@MainActor
struct SnapshotTests {

    /// MDP_SNAPSHOT_FONT=serif|monospaced 可切换字体
    static var snapshotStyle: ReaderStyle {
        var s = ReaderStyle.default
        if let f = ProcessInfo.processInfo.environment["MDP_SNAPSHOT_FONT"].flatMap(ReaderFontFamily.init(rawValue:)) {
            s.fontFamily = f
        }
        return s
    }

    @Test("渲染示例文档快照", .enabled(if: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"] != nil))
    func renderSample() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"]!)
        let source = ProcessInfo.processInfo.environment["MDP_SNAPSHOT_SOURCE"]
            ?? #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/SnapshotTests.swift", with: "SampleDocument.md")
        let md = try String(contentsOfFile: source, encoding: .utf8)
        let parsed = MarkdownASTParser.parse(markdown: md)

        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let tv = ReaderTextView.make()
            tv.appearance = NSAppearance(named: appearance)
            tv.frame = NSRect(x: 0, y: 0, width: 1000, height: 100)
            let rendered = ReaderRenderer(style: Self.snapshotStyle, baseURL: URL(fileURLWithPath: source).deletingLastPathComponent())
                .render(parsed.blocks)
            tv.textStorage?.setAttributedString(rendered.text)
            tv.layoutManager!.ensureLayout(for: tv.textContainer!)
            let h = tv.layoutManager!.usedRect(for: tv.textContainer!).height + 60
            tv.setFrameSize(NSSize(width: 1000, height: h))

            let rep = tv.bitmapImageRepForCachingDisplay(in: tv.bounds)!
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                tv.cacheDisplay(in: tv.bounds, to: rep)
            }
            try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("reader-\(name).png"))
        }
    }

    @Test("渲染 Quick Look 缩略图快照", .enabled(if: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"] != nil))
    func renderThumbnail() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"]!)
        let source = #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/SnapshotTests.swift", with: "SampleDocument.md")
        let md = try String(contentsOfFile: source, encoding: .utf8)
        let size = CGSize(width: 256, height: 330)
        let draw = QuickLookSupport.thumbnailDrawing(markdown: md, size: size)

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 660, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        #expect(draw())
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("thumbnail.png"))
    }

    @Test("渲染编辑器行号快照", .enabled(if: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"] != nil))
    func renderEditor() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"]!)
        let source = #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/SnapshotTests.swift", with: "SampleDocument.md")
        let md = try String(contentsOfFile: source, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = window.contentView!.bounds
        window.contentView!.addSubview(scrollView)
        let tv = scrollView.documentView as! NSTextView
        tv.font = NativeEditorView.editorFont(size: 13.5)
        tv.textContainerInset = NSSize(width: 24, height: 20)
        tv.string = md + "\n"
        let ruler = LineNumberRulerView(textView: tv)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        ruler.setFontSize(13.5)
        tv.setSelectedRange(NSRange(location: 40, length: 0))
        scrollView.layoutSubtreeIfNeeded()
        tv.textLayoutManager?.ensureLayout(for: tv.textLayoutManager!.documentRange)

        #expect(tv.textLayoutManager != nil, "加了行号栏后仍是 TextKit 2")

        let rep = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds)!
        scrollView.cacheDisplay(in: scrollView.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("editor.png"))

        // 滚到末尾再拍一张，看文末空行的行号
        tv.scrollToEndOfDocument(nil)
        scrollView.layoutSubtreeIfNeeded()
        let rep2 = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds)!
        scrollView.cacheDisplay(in: scrollView.bounds, to: rep2)
        try rep2.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("editor-end.png"))
    }

    @Test("渲染编辑器源码着色快照", .enabled(if: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"] != nil))
    func renderEditorHighlighting() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"]!)
        let md = """
        # 标题

        正文 **加粗** 和 `code`，[链接](https://a.b)。

        ```swift
        let a = 1
        // 注释里的 **不是加粗**
        - 不是列表
        ```

        - 列表项
        > 引用
        """
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 360),
                              styleMask: [.titled], backing: .buffered, defer: false)
        var bound = md
        let editor = NativeEditorView(text: Binding(get: { bound }, set: { bound = $0 }), fontSize: 14, highlighting: true)
        let host = NSHostingView(rootView: editor.frame(width: 600, height: 360))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("editor-highlight.png"))
    }

    @Test("渲染插入图片说明弹窗", .enabled(if: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"] != nil))
    func renderImageNotice() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MDP_SNAPSHOT_DIR"]!)
        let alert = MarkdownTextView.imageNoticeAlert(documentURL: URL(fileURLWithPath: "/Users/me/笔记/周报.md"))
        alert.layout()
        let view = alert.window.contentView!
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("image-notice.png"))
    }
}
