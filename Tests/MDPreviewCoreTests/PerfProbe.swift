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
}
