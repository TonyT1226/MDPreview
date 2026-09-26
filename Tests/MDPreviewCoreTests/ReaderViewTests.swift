import Testing
import AppKit
import SwiftUI
@testable import MDPreviewCore

@Suite("阅读视图交互")
@MainActor
struct ReaderViewTests {

    private func makeTextView(_ md: String, width: CGFloat = 800) -> (ReaderTextView, RenderedDocument) {
        let parsed = MarkdownASTParser.parse(markdown: md)
        let doc = ReaderRenderer(style: .default).render(parsed.blocks)
        let tv = ReaderTextView.make()
        tv.frame = NSRect(x: 0, y: 0, width: width, height: 100)
        tv.pieces.update(to: parsed.blocks, renderer: ReaderRenderer(style: .default), storage: tv.textStorage!)
        tv.layoutManager!.ensureLayout(for: tv.textContainer!)
        tv.sizeToFit()
        return (tv, doc)
    }

    @Test("点中复选框返回源行号与当前状态；点正文不触发")
    func checkboxHitTest() throws {
        let (tv, doc) = makeTextView("# 清单\n\n- [ ] 第一项\n- [x] 第二项\n")
        let storage = try #require(tv.textStorage)

        var boxes: [Int] = []
        storage.enumerateAttribute(.mdTaskOrdinal, in: NSRange(location: 0, length: storage.length)) { v, r, _ in
            if v != nil { boxes.append(r.location) }
        }
        #expect(boxes.count == 2)

        for (i, loc) in boxes.enumerated() {
            let rect = try #require(tv.rect(forCharacterAt: loc))
            let hit = tv.taskCheckbox(at: NSPoint(x: rect.midX, y: rect.midY))
            #expect(hit?.0 == 2 + i)
            #expect(hit?.1 == (i == 1))
        }

        let textLoc = (doc.text.string as NSString).range(of: "第一项").location + 1
        let textRect = try #require(tv.rect(forCharacterAt: textLoc))
        #expect(tv.taskCheckbox(at: NSPoint(x: textRect.midX, y: textRect.midY)) == nil)
    }

    @Test("宽窗口时正文居中，版心不超过设定宽度")
    func contentWidthCentering() {
        let (tv, _) = makeTextView("正文", width: 1600)
        tv.contentWidth = 800
        tv.setFrameSize(NSSize(width: 1600, height: tv.frame.height))
        #expect(tv.textContainerInset.width == 400)
        tv.setFrameSize(NSSize(width: 600, height: tv.frame.height))
        #expect(tv.textContainerInset.width == ReaderTextView.minHorizontalInset)
    }

    @Test("TOC 跳转把标题滚到视口顶部附近")
    func scrollToHeading() throws {
        let body = (1...80).map { "段落 \($0)" }.joined(separator: "\n\n")
        let md = "# 开头\n\n\(body)\n\n## 末尾标题\n\n\(body)\n"
        let parsed = MarkdownASTParser.parse(markdown: md)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        let tv = ReaderTextView.make()
        tv.autoresizingMask = [.width]
        tv.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        scrollView.documentView = tv

        var target: String? = nil
        var active: String? = nil
        let rep = ReaderTextRepresentable(
            blocks: parsed.blocks, style: .default, baseURL: nil,
            targetScrollId: Binding(get: { target }, set: { target = $0 }),
            activeHeadingId: Binding(get: { active }, set: { active = $0 }),
            onToggleTask: { _, _ in })
        let c = ReaderTextRepresentable.Coordinator()
        c.parent = rep
        c.textView = tv
        c.scrollView = scrollView
        c.renderIfNeeded(blocks: parsed.blocks, style: .default, baseURL: nil)
        tv.sizeToFit()

        let lastID = try #require(parsed.tocItems.first?.children.last?.id)
        c.scroll(toHeading: lastID, animated: false)
        let y = scrollView.contentView.bounds.origin.y
        #expect(y > 1000)

        let headingLoc = (tv.string as NSString).range(of: "末尾标题").location
        let rect = try #require(tv.rect(forCharacterAt: headingLoc))
        #expect(rect.minY >= y)
        #expect(rect.minY - y < 60)
    }
}
