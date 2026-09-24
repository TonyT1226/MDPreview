import SwiftUI
import AppKit

/// 基于 TextKit 2 与 `NSTextView` 的纯原生极简编辑器。
public struct NativeEditorView: NSViewRepresentable {
    @Binding public var text: String
    /// 编辑器字号（跟随阅读区字号偏好，略小一号的等宽体）
    public var fontSize: CGFloat
    /// Markdown 源码着色（偏好设置里的开关，默认关）。
    /// `MarkdownSourceHighlighter` + `renderingAttributesValidator` 走显示层属性，
    /// 不进 undo 栈、不打断输入法。
    public var highlighting: Bool
    /// 左侧行号栏（光标所在行加深）
    public var lineNumbers: Bool

    public init(text: Binding<String>, fontSize: CGFloat = 13.5, highlighting: Bool = false, lineNumbers: Bool = true) {
        self._text = text
        self.fontSize = fontSize
        self.highlighting = highlighting
        self.lineNumbers = lineNumbers
    }

    static func editorFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.font = Self.editorFont(size: fontSize)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 24, height: 20)

        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false // Markdown 源码里全是误报
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true

        textView.string = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        context.coordinator.setHighlighting(highlighting)
        context.coordinator.setLineNumbers(lineNumbers, fontSize: fontSize)
        textView.setAccessibilityLabel(L.editorAccessibilityLabel)

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator,
                                               selector: #selector(Coordinator.didScroll(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        let font = Self.editorFont(size: fontSize)
        if textView.font != font { textView.font = font }
        context.coordinator.setHighlighting(highlighting)
        context.coordinator.setLineNumbers(lineNumbers, fontSize: fontSize)

        // 只在「外部变更」时回灌：正在编辑 / 正在用输入法组字时绝不打断
        guard textView.string != text else { return }
        if context.coordinator.isEditing || textView.hasMarkedText() { return }

        let selectedRanges = textView.selectedRanges
        textView.string = text
        let clamped = selectedRanges.compactMap { value -> NSValue? in
            let r = value.rangeValue
            guard r.location <= textView.string.utf16.count else { return nil }
            let len = min(r.length, textView.string.utf16.count - r.location)
            return NSValue(range: NSRange(location: r.location, length: len))
        }
        if !clamped.isEmpty {
            textView.selectedRanges = clamped
        }
        if highlighting {
            context.coordinator.recomputeTokens(for: text)
        }
        context.coordinator.ruler?.textDidChange()
    }

    public static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditorView
        weak var textView: NSTextView?
        private(set) var isEditing = false

        private var tokens: [MarkdownSourceHighlighter.Token] = []
        private var rehighlightTask: Task<Void, Never>?

        init(_ parent: NativeEditorView) {
            self.parent = parent
        }

        // MARK: - 编辑事件

        public func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        public func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            ruler?.textDidChange()
            // 组字未提交时不写回，避免拼音输入被打断
            if tv.hasMarkedText() { return }
            let newText = tv.string
            if parent.text != newText {
                parent.text = newText
            }
            if highlightingOn {
                scheduleRehighlight(for: newText)
            }
        }

        // MARK: - 回车 / Tab：列表续写与缩进

        public func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // 输入法组字时回车 / Tab 属于输入法，一律不介入
            guard !textView.hasMarkedText() else { return false }
            let selection = textView.selectedRange()
            let edit: TextEdit?
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                edit = MarkdownEditing.newline(text: textView.string, selection: selection)
            case #selector(NSResponder.insertTab(_:)):
                edit = MarkdownEditing.indent(text: textView.string, selection: selection, outdent: false)
            case #selector(NSResponder.insertBacktab(_:)):
                edit = MarkdownEditing.indent(text: textView.string, selection: selection, outdent: true)
            default:
                edit = nil
            }
            guard let edit else { return false }
            textView.apply(edit)
            return true
        }

        // MARK: - 行号

        private(set) var ruler: LineNumberRulerView?

        func setLineNumbers(_ on: Bool, fontSize: CGFloat) {
            guard let tv = textView, let scrollView = tv.enclosingScrollView else { return }
            if on, ruler == nil {
                let r = LineNumberRulerView(textView: tv)
                scrollView.verticalRulerView = r
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true
                ruler = r
            } else if !on, ruler != nil {
                scrollView.rulersVisible = false
                scrollView.hasVerticalRuler = false
                scrollView.verticalRulerView = nil
                ruler = nil
            }
            ruler?.setFontSize(fontSize)
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            ruler?.needsDisplay = true
        }

        @objc func didScroll(_ note: Notification) {
            ruler?.needsDisplay = true
        }

        // MARK: - 源码着色

        private(set) var highlightingOn = false

        /// 开 / 关源码着色：装上或卸下 TextKit 2 的显示层属性验证器
        func setHighlighting(_ on: Bool) {
            guard on != highlightingOn, let tv = textView, let tlm = tv.textLayoutManager else { return }
            highlightingOn = on
            if on {
                tlm.renderingAttributesValidator = { [weak self] tlm, fragment in
                    MainActor.assumeIsolated {
                        self?.applyRenderingAttributes(tlm, fragment)
                    }
                }
                recomputeTokens(for: tv.string)
            } else {
                rehighlightTask?.cancel()
                tlm.renderingAttributesValidator = nil
                tokens = []
                // 清掉已画上的颜色
                tlm.removeRenderingAttribute(.foregroundColor, for: tlm.documentRange)
                tlm.removeRenderingAttribute(.strikethroughStyle, for: tlm.documentRange)
                tv.needsDisplay = true
            }
        }

        func recomputeTokens(for text: String) {
            tokens = MarkdownSourceHighlighter.tokens(in: text)
            invalidateRendering()
        }

        private func scheduleRehighlight(for text: String) {
            rehighlightTask?.cancel()
            rehighlightTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                self?.recomputeTokens(for: text)
            }
        }

        private func invalidateRendering() {
            guard let tlm = textView?.textLayoutManager else { return }
            tlm.invalidateRenderingAttributes(for: tlm.documentRange)
            textView?.needsDisplay = true
        }

        /// `renderingAttributesValidator` 回调：给这个 fragment 覆盖上颜色
        func applyRenderingAttributes(_ tlm: NSTextLayoutManager, _ fragment: NSTextLayoutFragment) {
            guard let tcm = tlm.textContentManager else { return }
            let fragRange = fragment.rangeInElement
            let fragStart = tlm.offset(from: tlm.documentRange.location, to: fragRange.location)
            let fragEnd = tlm.offset(from: tlm.documentRange.location, to: fragRange.endLocation)
            guard fragEnd > fragStart else { return }
            let fragNS = NSRange(location: fragStart, length: fragEnd - fragStart)

            for token in MarkdownSourceHighlighter.tokens(tokens, startingIn: fragNS) {
                guard let hit = token.range.intersection(fragNS), hit.length > 0 else { continue }
                guard let start = tcm.location(tlm.documentRange.location, offsetBy: hit.location),
                      let end = tcm.location(start, offsetBy: hit.length),
                      let range = NSTextRange(location: start, end: end) else { continue }
                tlm.setRenderingAttributes(Self.attributes(for: token.kind), for: range)
            }
        }

        private static func attributes(for kind: MarkdownSourceHighlighter.Kind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .heading:
                return [.foregroundColor: NSColor.systemBlue]
            case .strong:
                return [.foregroundColor: NSColor.systemPurple]
            case .emphasis:
                return [.foregroundColor: NSColor.systemTeal]
            case .strikethrough:
                return [.foregroundColor: NSColor.tertiaryLabelColor,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue]
            case .inlineCode, .codeFence:
                return [.foregroundColor: NSColor.systemBrown]
            case .listMarker:
                return [.foregroundColor: NSColor.systemOrange]
            case .blockquote:
                return [.foregroundColor: NSColor.systemGreen]
            case .link:
                return [.foregroundColor: NSColor.linkColor]
            case .thematicBreak:
                return [.foregroundColor: NSColor.tertiaryLabelColor]
            }
        }
    }
}

// MARK: - 应用编辑与快捷格式（经响应链到达当前编辑器）

extension NSTextView {

    /// 以一次可撤销的替换应用编辑，并设置选区
    func apply(_ edit: TextEdit) {
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        setSelectedRange(edit.selection)
        scrollRangeToVisible(edit.selection)
    }

    /// 只对 Markdown 编辑器生效（阅读区、查找栏等其他文本视图也在响应链上）
    private var isMarkdownEditor: Bool {
        isEditable && delegate is NativeEditorView.Coordinator && !hasMarkedText()
    }

    @objc func mdToggleBold(_ sender: Any?) { applyFormat { MarkdownEditing.toggleInline(.bold, text: $0, selection: $1) } }
    @objc func mdToggleItalic(_ sender: Any?) { applyFormat { MarkdownEditing.toggleInline(.italic, text: $0, selection: $1) } }
    @objc func mdToggleCode(_ sender: Any?) { applyFormat { MarkdownEditing.toggleInline(.code, text: $0, selection: $1) } }
    @objc func mdInsertLink(_ sender: Any?) { applyFormat { MarkdownEditing.insertLink(text: $0, selection: $1) } }

    private func applyFormat(_ make: (String, NSRange) -> TextEdit) {
        guard isMarkdownEditor else { NSSound.beep(); return }
        apply(make(string, selectedRange()))
    }
}

/// 「格式」菜单命令：发给响应链上的第一个编辑器
@MainActor
public enum MarkdownFormatCommand {
    case bold, italic, code, link

    public func send() {
        let selector: Selector
        switch self {
        case .bold: selector = #selector(NSTextView.mdToggleBold(_:))
        case .italic: selector = #selector(NSTextView.mdToggleItalic(_:))
        case .code: selector = #selector(NSTextView.mdToggleCode(_:))
        case .link: selector = #selector(NSTextView.mdInsertLink(_:))
        }
        if !NSApp.sendAction(selector, to: nil, from: nil) { NSSound.beep() }
    }
}
