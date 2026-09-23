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

    public init(text: Binding<String>, fontSize: CGFloat = 13.5, highlighting: Bool = false) {
        self._text = text
        self.fontSize = fontSize
        self.highlighting = highlighting
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
        textView.setAccessibilityLabel(L.editorAccessibilityLabel)

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        let font = Self.editorFont(size: fontSize)
        if textView.font != font { textView.font = font }
        context.coordinator.setHighlighting(highlighting)

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
                try? await Task.sleep(for: .milliseconds(120))
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

            for token in tokens {
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
