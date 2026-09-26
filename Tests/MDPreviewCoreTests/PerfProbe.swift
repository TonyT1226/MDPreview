import Testing
import AppKit
@testable import MDPreviewCore

@Suite("性能探针（手动）")
@MainActor
struct PerfProbe {
    @Test("大文档渲染耗时", .enabled(if: ProcessInfo.processInfo.environment["MDP_PERF"] != nil))
    func bigDoc() throws {
        let source = #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/PerfProbe.swift", with: "SampleDocument.md")
        let one = try String(contentsOfFile: source, encoding: .utf8)
        let md = Array(repeating: one, count: 60).joined(separator: "\n\n")
        let t0 = Date()
        let parsed = MarkdownASTParser.parse(markdown: md)
        let t1 = Date()
        let doc = ReaderRenderer(style: .default).render(parsed.blocks)
        let t2 = Date()
        let tv = ReaderTextView.make()
        tv.frame = NSRect(x: 0, y: 0, width: 900, height: 100)
        tv.textStorage?.setAttributedString(doc.text)
        tv.layoutManager!.ensureLayout(for: tv.textContainer!)
        let t3 = Date()
        print("PERF bytes=\(md.utf8.count) parse=\(t1.timeIntervalSince(t0)) render=\(t2.timeIntervalSince(t1)) layout=\(t3.timeIntervalSince(t2))")
    }

    @Test("编辑器源码着色扫描耗时", .enabled(if: ProcessInfo.processInfo.environment["MDP_PERF"] != nil))
    func sourceHighlighter() throws {
        let source = #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/PerfProbe.swift", with: "SampleDocument.md")
        let one = try String(contentsOfFile: source, encoding: .utf8)
        let md = Array(repeating: one, count: 60).joined(separator: "\n\n")
        let t0 = Date()
        let tokens = MarkdownSourceHighlighter.tokens(in: md)
        let t1 = Date()
        print("PERF highlighter bytes=\(md.utf8.count) tokens=\(tokens.count) scan=\(t1.timeIntervalSince(t0))")
    }

    @Test("阅读区增量更新耗时（改一个字）", .enabled(if: ProcessInfo.processInfo.environment["MDP_PERF"] != nil))
    func incrementalUpdate() throws {
        let source = #filePath.replacingOccurrences(of: "Tests/MDPreviewCoreTests/PerfProbe.swift", with: "SampleDocument.md")
        let one = try String(contentsOfFile: source, encoding: .utf8)
        let md = Array(repeating: one, count: 60).joined(separator: "\n\n")
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        let tv = ReaderTextView.make()
        tv.autoresizingMask = [.width]
        tv.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        scrollView.documentView = tv
        let c = ReaderTextRepresentable.Coordinator()
        c.textView = tv
        c.scrollView = scrollView

        let before = MarkdownASTParser.parse(markdown: md).blocks
        let t0 = Date()
        c.renderIfNeeded(blocks: before, style: .default, baseURL: nil)
        let t1 = Date()
        // 滚到中间，改中间附近的一个字
        let mid = md.utf16.count / 2
        let edited = (md as NSString).replacingCharacters(in: NSRange(location: mid, length: 0), with: "字")
        let after = MarkdownASTParser.parse(markdown: edited).blocks
        tv.layoutManager!.ensureLayout(for: tv.textContainer!)
        tv.sizeToFit()
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: tv.frame.height / 2))
        // 来回切换几次取平均：每次都只有中间一块变
        var total: TimeInterval = 0
        let rounds = 10
        for r in 0..<rounds {
            let t2 = Date()
            c.renderIfNeeded(blocks: r % 2 == 0 ? after : before, style: .default, baseURL: nil)
            total += Date().timeIntervalSince(t2)
        }
        // 对照：整篇重排（v1.4 的做法）
        let t4 = Date()
        c.renderIfNeeded(blocks: after, style: .default, baseURL: nil, force: true)
        let full = Date().timeIntervalSince(t4)
        print("PERF incremental bytes=\(md.utf8.count) first=\(t1.timeIntervalSince(t0)) update(avg)=\(total / Double(rounds)) full=\(full)")
    }
}
