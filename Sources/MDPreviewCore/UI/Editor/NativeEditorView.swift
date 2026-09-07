import SwiftUI
import AppKit

/// 基于 TextKit 2 与 NSTextView 的纯原生极简编辑器
public struct NativeEditorView: NSViewRepresentable {
    @Binding public var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> NSScrollView {
        // 使用 TextKit 2（NSTextLayoutManager）装配的可滚动 NSTextView
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
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

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

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
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditorView
        weak var textView: NSTextView?
        private(set) var isEditing = false

        init(_ parent: NativeEditorView) {
            self.parent = parent
        }

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
        }
    }
}
