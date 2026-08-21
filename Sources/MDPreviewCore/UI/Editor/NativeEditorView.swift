import SwiftUI
import AppKit

/// 基于 TextKit 2 与 NSTextView 的纯原生极简编辑器
public struct NativeEditorView: NSViewRepresentable {
    @Binding public var text: String
    public var onTextChange: ((String) -> Void)?

    public init(text: Binding<String>, onTextChange: ((String) -> Void)? = nil) {
        self._text = text
        self.onTextChange = onTextChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // 排版与文本特性配置
        textView.font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.string = text
        textView.delegate = context.coordinator

        context.coordinator.textView = textView
        scrollView.documentView = textView

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditorView
        weak var textView: NSTextView?

        init(_ parent: NativeEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let newText = tv.string
            if parent.text != newText {
                parent.text = newText
                parent.onTextChange?(newText)
            }
        }
    }
}
