import SwiftUI
import AppKit

/// 阅读视图：整篇文档渲染成一个只读 `NSTextView`，
/// 可跨段落 / 跨列表连续选择，支持 ⌘F 查找、查词、链接点击、任务勾选回写、TOC 跳转与滚动联动。
public struct NativeReaderView: View {
    public let parsedDoc: ParsedDocument
    @Binding public var targetScrollId: String?
    @Binding public var activeHeadingId: String?
    public var baseURL: URL?
    public var onToggleTask: @Sendable (Int, Bool) -> Void

    @AppStorage(PrefKey.fontSize) private var fontSize = Double(ReaderStyle.default.fontSize)
    @AppStorage(PrefKey.lineHeight) private var lineHeight = Double(ReaderStyle.default.lineHeight)
    @AppStorage(PrefKey.contentWidth) private var contentWidth = Double(ReaderStyle.default.contentWidth)
    @AppStorage(PrefKey.fontFamily) private var fontFamily = ReaderStyle.default.fontFamily.rawValue

    public init(
        parsedDoc: ParsedDocument,
        targetScrollId: Binding<String?>,
        activeHeadingId: Binding<String?> = .constant(nil),
        baseURL: URL? = nil,
        onToggleTask: @escaping @Sendable (Int, Bool) -> Void = { _, _ in }
    ) {
        self.parsedDoc = parsedDoc
        self._targetScrollId = targetScrollId
        self._activeHeadingId = activeHeadingId
        self.baseURL = baseURL
        self.onToggleTask = onToggleTask
    }

    private var style: ReaderStyle {
        ReaderStyle(fontSize: fontSize, lineHeight: lineHeight, contentWidth: contentWidth,
                    fontFamily: ReaderFontFamily(rawValue: fontFamily) ?? .system)
    }

    public var body: some View {
        ReaderTextRepresentable(
            blocks: parsedDoc.blocks,
            style: style,
            baseURL: baseURL,
            targetScrollId: $targetScrollId,
            activeHeadingId: $activeHeadingId,
            onToggleTask: onToggleTask
        )
        .overlay {
            if parsedDoc.blocks.isEmpty { emptyState }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
                .accessibilityHidden(true)
            Text(L.emptyDocument).font(.system(size: 14)).foregroundColor(.secondary)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - NSViewRepresentable

struct ReaderTextRepresentable: NSViewRepresentable {
    let blocks: [MarkdownBlock]
    let style: ReaderStyle
    let baseURL: URL?
    @Binding var targetScrollId: String?
    @Binding var activeHeadingId: String?
    let onToggleTask: @Sendable (Int, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ReaderTextView.make()
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)

        let c = context.coordinator
        c.textView = textView
        c.scrollView = scrollView
        textView.delegate = c
        textView.onToggleTask = { line, checked in c.parent?.onToggleTask(line, checked) }

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.boundsChanged(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.remoteImageLoaded(_:)),
                                               name: RemoteImageCache.didLoad, object: nil)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.renderIfNeeded(blocks: blocks, style: style, baseURL: baseURL)

        if let target = targetScrollId {
            c.scroll(toHeading: target, animated: true)
            // 复位，让同一个大纲项可以再次点击
            DispatchQueue.main.async { self.targetScrollId = nil }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ReaderTextRepresentable?
        weak var textView: ReaderTextView?
        weak var scrollView: NSScrollView?

        private var lastBlocks: [MarkdownBlock]?
        private var lastStyle: ReaderStyle?
        private var lastBaseURL: URL?
        private var headings: [(id: String, location: Int)] = []
        private var lastReportedHeading: String?

        func renderIfNeeded(blocks: [MarkdownBlock], style: ReaderStyle, baseURL: URL?, force: Bool = false) {
            guard let textView else { return }
            if !force, lastBlocks == blocks, lastStyle == style, lastBaseURL == baseURL { return }
            let styleChanged = lastStyle != style
            lastBlocks = blocks
            lastStyle = style
            lastBaseURL = baseURL

            let renderer = ReaderRenderer(style: style, baseURL: baseURL, imageProvider: RemoteImageCache.shared)
            let doc = renderer.render(blocks)
            headings = doc.headings

            // 保持滚动位置：内容更新时视口顶部停在原处
            let origin = scrollView?.contentView.bounds.origin ?? .zero
            let selection = textView.selectedRanges
            textView.contentWidth = style.contentWidth
            textView.textStorage?.setAttributedString(doc.text)
            if styleChanged { textView.updateInsets() }
            let length = textView.string.utf16.count
            let clamped = selection.compactMap { v -> NSValue? in
                let r = v.rangeValue
                guard r.location <= length else { return nil }
                return NSValue(range: NSRange(location: r.location, length: min(r.length, length - r.location)))
            }
            textView.selectedRanges = clamped.isEmpty ? [NSValue(range: NSRange(location: 0, length: 0))] : clamped
            if let scrollView {
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                scrollView.contentView.scroll(to: origin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            reportActiveHeading()
        }

        // MARK: TOC 跳转

        func scroll(toHeading id: String, animated: Bool) {
            guard let textView, let scrollView,
                  let location = headings.first(where: { $0.id == id })?.location,
                  let rect = textView.rect(forCharacterAt: location) else { return }
            let clip = scrollView.contentView
            let maxY = max(0, textView.frame.height - clip.bounds.height)
            let target = NSPoint(x: 0, y: min(max(0, rect.minY - 12), maxY))
            if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    clip.animator().setBoundsOrigin(target)
                }
            } else {
                clip.scroll(to: target)
            }
            scrollView.reflectScrolledClipView(clip)
        }

        // MARK: 滚动联动

        @objc func boundsChanged(_ note: Notification) {
            reportActiveHeading()
        }

        private func reportActiveHeading() {
            guard let textView, let scrollView, !headings.isEmpty else { return }
            let visible = scrollView.contentView.bounds
            // 视口顶部往下 ~80pt 处的字符之前的最后一个标题即当前章节
            let probe = NSPoint(x: textView.textContainerOrigin.x + 1, y: visible.minY + 80)
            let index = textView.characterIndexForInsertion(at: probe)
            var current = headings.first?.id
            for h in headings where h.location <= index { current = h.id }
            guard current != lastReportedHeading else { return }
            lastReportedHeading = current
            // 推到下一轮 runloop，避免在 SwiftUI 视图更新中改状态
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent?.activeHeadingId != current else { return }
                self.parent?.activeHeadingId = current
            }
        }

        @objc func remoteImageLoaded(_ note: Notification) {
            guard let blocks = lastBlocks, let style = lastStyle else { return }
            renderIfNeeded(blocks: blocks, style: style, baseURL: lastBaseURL, force: true)
        }

        // MARK: 链接

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            if let u = link as? URL { url = u } else if let s = link as? String { url = URL(string: s) } else { url = nil }
            guard let url else { return false }

            // 页内锚点 #heading
            if url.scheme == nil, let fragment = url.fragment, url.path.isEmpty {
                if let id = headingID(forAnchor: fragment) {
                    scroll(toHeading: id, animated: true)
                }
                return true
            }
            // 相对路径 → 基于文档目录解析
            var resolved = url
            if url.scheme == nil {
                guard let base = parent?.baseURL else { return false }
                let path = url.path.removingPercentEncoding ?? url.path
                resolved = URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
            }
            if resolved.isFileURL, ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn"].contains(resolved.pathExtension.lowercased()) {
                NSDocumentController.shared.openDocument(withContentsOf: resolved, display: true) { _, _, _ in }
            } else {
                NSWorkspace.shared.open(resolved)
            }
            return true
        }

        /// GitHub 风格锚点：小写、空格变 -、去掉标点
        private func headingID(forAnchor anchor: String) -> String? {
            guard let storage = textView?.textStorage else { return nil }
            let wanted = (anchor.removingPercentEncoding ?? anchor).lowercased()
            for h in headings {
                let range = (storage.string as NSString).paragraphRange(for: NSRange(location: h.location, length: 0))
                let title = (storage.string as NSString).substring(with: range)
                if Self.slug(title) == wanted { return h.id }
            }
            return nil
        }

        static func slug(_ title: String) -> String {
            let lowered = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var out = ""
            for ch in lowered {
                if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                    out.append(ch)
                } else if ch == " " {
                    out.append("-")
                }
            }
            return out
        }
    }
}

// MARK: - 只读文本视图

final class ReaderTextView: NSTextView {
    var onToggleTask: ((Int, Bool) -> Void)?
    /// 版心宽度；视图更宽时左右留白居中
    var contentWidth: CGFloat = ReaderStyle.default.contentWidth
    /// 关掉后不再按版心自动算左右边距（打印时贴满可打印区域）
    var autoInsets = true

    static let minHorizontalInset: CGFloat = 32
    static let verticalInset: CGFloat = 28

    /// 显式搭一套 TextKit 1 栈（NSTextBlock / NSTextTable 需要）
    static func make() -> ReaderTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)

        let tv = ReaderTextView(frame: .zero, textContainer: container)
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = true
        tv.importsGraphics = false
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        tv.textContainerInset = NSSize(width: minHorizontalInset, height: verticalInset)
        tv.setAccessibilityLabel(L.readerAccessibilityLabel)
        return tv
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateInsets()
    }

    func updateInsets() {
        guard autoInsets else { return }
        let horizontal = max(Self.minHorizontalInset, ((frame.width - contentWidth) / 2).rounded())
        if textContainerInset.width != horizontal {
            textContainerInset = NSSize(width: horizontal, height: Self.verticalInset)
        }
    }

    /// 某字符所在行在视图坐标系里的矩形
    func rect(forCharacterAt location: Int) -> NSRect? {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        let loc = min(location, storage.length - 1)
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: loc + 1))
        let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: loc, length: 1), actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    // MARK: 任务复选框点击

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let (line, checked) = taskCheckbox(at: point) {
            onToggleTask?(line, !checked)
            return
        }
        super.mouseDown(with: event)
    }

    private func taskCheckbox(at point: NSPoint) -> (Int, Bool)? {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let glyph = layoutManager.glyphIndex(for: local, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyph)
        guard charIndex < storage.length,
              let line = storage.attribute(.mdTaskSourceLine, at: charIndex, effectiveRange: nil) as? Int else { return nil }
        // 确认点在复选框图形上，而不只是「最近的字符」
        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        guard rect.insetBy(dx: -3, dy: -3).contains(local) else { return nil }
        let checked = storage.attribute(.mdTaskChecked, at: charIndex, effectiveRange: nil) as? Bool ?? false
        return (line, checked)
    }
}
