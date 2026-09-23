import Testing
import AppKit
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
}
