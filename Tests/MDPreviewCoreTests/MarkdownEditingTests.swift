import Testing
import Foundation
import AppKit
import SwiftUI
@testable import MDPreviewCore

/// 用 `|` 标出光标、`«` `»` 标出选区的简写，便于写用例
private func parse(_ marked: String) -> (String, NSRange) {
    var text = ""
    var start: Int?
    var end: Int?
    for ch in marked {
        switch ch {
        case "|": start = (text as NSString).length; end = start
        case "«": start = (text as NSString).length
        case "»": end = (text as NSString).length
        default: text.append(ch)
        }
    }
    let s = start ?? 0
    return (text, NSRange(location: s, length: (end ?? s) - s))
}

private func render(_ text: String, _ sel: NSRange) -> String {
    let ns = NSMutableString(string: text)
    if sel.length == 0 {
        ns.insert("|", at: sel.location)
    } else {
        ns.insert("»", at: NSMaxRange(sel))
        ns.insert("«", at: sel.location)
    }
    return ns as String
}

private func run(_ marked: String, _ op: (String, NSRange) -> TextEdit?) -> String? {
    let (text, sel) = parse(marked)
    guard let edit = op(text, sel) else { return nil }
    return render(edit.applied(to: text), edit.selection)
}

@Suite("编辑器：快捷格式")
struct InlineFormatTests {
    private func bold(_ s: String) -> String? { run(s) { MarkdownEditing.toggleInline(.bold, text: $0, selection: $1) } }
    private func italic(_ s: String) -> String? { run(s) { MarkdownEditing.toggleInline(.italic, text: $0, selection: $1) } }
    private func code(_ s: String) -> String? { run(s) { MarkdownEditing.toggleInline(.code, text: $0, selection: $1) } }
    private func link(_ s: String) -> String? { run(s) { MarkdownEditing.insertLink(text: $0, selection: $1) } }

    @Test("包裹选区，再按一次取消")
    func wrapAndUnwrap() {
        #expect(bold("前 «中文» 后") == "前 **«中文»** 后")
        #expect(bold("前 **«中文»** 后") == "前 «中文» 后")
        #expect(italic("a «b» c") == "a *«b»* c")
        #expect(italic("a *«b»* c") == "a «b» c")
        #expect(code("run «swift test»") == "run `«swift test»`")
        #expect(code("run `«swift test»`") == "run «swift test»")
    }

    @Test("选中的文字自带标记时去掉标记")
    func unwrapSelectedMarkers() {
        #expect(bold("x «**y**» z") == "x «y» z")
        #expect(code("x «`y`» z") == "x «y» z")
    }

    @Test("加粗与斜体互不误判（*** 同时有两种）")
    func boldItalicDisambiguation() {
        #expect(italic("**«x»**") == "***«x»***")      // 加粗里再加斜体
        #expect(bold("*«x»*") == "***«x»***")          // 斜体里再加粗
        #expect(italic("***«x»***") == "**«x»**")      // 去掉斜体，保留加粗
        #expect(bold("***«x»***") == "*«x»*")          // 去掉加粗，保留斜体
    }

    @Test("无选区：插入一对标记，光标在中间；再按一次删掉空标记")
    func emptySelection() {
        #expect(bold("a |b") == "a **|**b")
        #expect(bold("a **|**b") == "a |b")
        #expect(code("|") == "`|`")
    }

    @Test("链接")
    func links() {
        #expect(link("见 «文档» 说明") == "见 [文档](|) 说明")
        #expect(link("见 «https://apple.com» 说明") == "见 [|](https://apple.com) 说明")
        #expect(link("x |y") == "x [|]()y")
    }
}

@Suite("编辑器：列表续写")
struct ListContinuationTests {
    private func enter(_ s: String) -> String? { run(s) { MarkdownEditing.newline(text: $0, selection: $1) } }

    @Test("续写各种列表标记")
    func continues() {
        #expect(enter("- 第一项|") == "- 第一项\n- |")
        #expect(enter("* a|") == "* a\n* |")
        #expect(enter("  + nested|") == "  + nested\n  + |")
        #expect(enter("1. 一|") == "1. 一\n2. |")
        #expect(enter("9) nine|") == "9) nine\n10) |")
        #expect(enter("- [x] 完成|") == "- [x] 完成\n- [ ] |")
        #expect(enter("- [ ] 待办|") == "- [ ] 待办\n- [ ] |")
    }

    @Test("光标在正文中间：后半段带到新项")
    func splitsItem() {
        #expect(enter("- 前半|后半") == "- 前半\n- |后半")
    }

    @Test("空列表项上回车：清掉标记退出列表")
    func exitsOnEmptyItem() {
        #expect(enter("- a\n- |") == "- a\n|")
        #expect(enter("- a\n- [ ] |") == "- a\n|")
        #expect(enter("1. a\n2. |") == "1. a\n|")
    }

    @Test("不介入：普通段落、有选区、光标在标记前、分割线、围栏代码块里")
    func ignores() {
        #expect(enter("普通段落|") == nil)
        #expect(enter("- «a»b") == nil)
        #expect(enter("|- a") == nil)
        #expect(enter("- - -|") == nil)
        #expect(enter("```\n- 代码里的横线|\n```") == nil)
    }
}

@Suite("编辑器：Tab 缩进")
struct IndentTests {
    private func tab(_ s: String) -> String? { run(s) { MarkdownEditing.indent(text: $0, selection: $1, outdent: false) } }
    private func backtab(_ s: String) -> String? { run(s) { MarkdownEditing.indent(text: $0, selection: $1, outdent: true) } }

    @Test("列表项整行缩进 / 反缩进，光标跟着走")
    func listItem() {
        #expect(tab("- a\n- b|") == "- a\n    - b|")
        #expect(backtab("- a\n    - b|") == "- a\n- b|")
        #expect(backtab("- a\n  - b|") == "- a\n- b|")
    }

    @Test("多行选区整体缩进，只动选中的行")
    func multiLine() {
        #expect(tab("x\n«a\nb»\ny") == "x\n    «a\n    b»\ny")
        #expect(backtab("x\n    «a\n    b»\ny") == "x\n«a\nb»\ny")
    }

    @Test("不介入：普通行上的光标、已经顶格还要反缩进")
    func ignores() {
        #expect(tab("普通|文字") == nil)
        #expect(backtab("- 顶格|") == nil)
    }
}

@Suite("编辑器：接到真实 NSTextView 上")
@MainActor
struct EditorIntegrationTests {

    private func makeEditor(_ text: String) -> (NSTextView, NativeEditorView.Coordinator, NSWindow) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let scroll = NSTextView.scrollableTextView()
        window.contentView = scroll
        let tv = scroll.documentView as! NSTextView
        tv.allowsUndo = true
        tv.string = text
        var bound = text
        let editor = NativeEditorView(text: Binding(get: { bound }, set: { bound = $0 }))
        let c = NativeEditorView.Coordinator(editor)
        c.textView = tv
        tv.delegate = c
        window.makeFirstResponder(tv)
        return (tv, c, window)
    }

    @Test("回车续写列表，一次撤销恢复原样")
    func enterContinuesListAndUndoes() {
        let (tv, c, window) = makeEditor("- 第一项")
        tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
        tv.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(tv.string == "- 第一项\n- ")
        #expect(tv.selectedRange().location == (tv.string as NSString).length)

        tv.breakUndoCoalescing()
        tv.undoManager?.undo()
        #expect(tv.string == "- 第一项")
        _ = (c, window)
    }

    @Test("Tab 缩进列表项；普通行上的 Tab 仍插入制表符")
    func tabBehaviour() {
        let (tv, c, window) = makeEditor("- a\n- b")
        tv.setSelectedRange(NSRange(location: 7, length: 0))
        tv.doCommand(by: #selector(NSResponder.insertTab(_:)))
        #expect(tv.string == "- a\n    - b")

        tv.string = "plain"
        tv.setSelectedRange(NSRange(location: 5, length: 0))
        tv.doCommand(by: #selector(NSResponder.insertTab(_:)))
        #expect(tv.string == "plain\t")
        _ = (c, window)
    }

    @Test("格式命令只作用于 Markdown 编辑器")
    func formatActions() {
        let (tv, c, window) = makeEditor("hello world")
        tv.setSelectedRange(NSRange(location: 6, length: 5))
        tv.mdToggleBold(nil)
        #expect(tv.string == "hello **world**")
        tv.mdToggleBold(nil)
        #expect(tv.string == "hello world")

        // 没有挂编辑器代理的文本视图（如阅读区）不受影响
        let other = NSTextView()
        other.string = "abc"
        other.setSelectedRange(NSRange(location: 0, length: 3))
        other.mdToggleBold(nil)
        #expect(other.string == "abc")
        _ = (c, window)
    }

    @Test("输入法组字时回车 / Tab 不介入，格式命令也不动")
    func respectsMarkedText() {
        let (tv, c, window) = makeEditor("- 项目")
        tv.setSelectedRange(NSRange(location: 4, length: 0))
        tv.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(tv.hasMarkedText())
        #expect(c.textView(tv, doCommandBy: #selector(NSResponder.insertNewline(_:))) == false)
        #expect(c.textView(tv, doCommandBy: #selector(NSResponder.insertTab(_:))) == false)
        let before = tv.string
        tv.mdToggleBold(nil)
        #expect(tv.string == before)
        _ = window
    }
}
