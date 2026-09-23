import AppKit

public extension NSAttributedString.Key {
    /// 标题段落：值为标题 id（与 TOCItem.id 一致）
    static let mdHeadingID = NSAttributedString.Key("MDPreview.headingID")
    /// 任务复选框字符：值为源文档行号（0 基，Int）
    static let mdTaskSourceLine = NSAttributedString.Key("MDPreview.taskSourceLine")
    /// 任务复选框字符：当前勾选状态（Bool）
    static let mdTaskChecked = NSAttributedString.Key("MDPreview.taskChecked")
}

/// 渲染结果：整篇文档一个 `NSAttributedString`，外加标题位置表（TOC 跳转 / 滚动联动用）
public struct RenderedDocument {
    public let text: NSAttributedString
    /// 按出现顺序排列的 (标题 id, 字符位置)
    public let headings: [(id: String, location: Int)]

    public init(text: NSAttributedString, headings: [(id: String, location: Int)]) {
        self.text = text
        self.headings = headings
    }
}

/// 远程图片的来源。命中缓存返回图片；未命中返回 nil 并在后台加载，加载完由调用方重渲染。
@MainActor
public protocol ReaderImageProvider: AnyObject {
    func image(for url: URL) -> NSImage?
    func hasFailed(_ url: URL) -> Bool
}

/// 把 `MarkdownBlock` 树排成一个 `NSAttributedString`，交给只读 `NSTextView`（TextKit 1）显示。
///
/// 用 TextKit 1 而不是 TextKit 2：代码块底色、引用竖线、标题下划线靠 `NSTextBlock`，
/// 表格靠 `NSTextTable`，这两者只有 TextKit 1 支持（TextKit 2 碰到会自动回退，不如一开始就用 1）。
@MainActor
public struct ReaderRenderer {

    public let style: ReaderStyle
    public let baseURL: URL?
    public weak var imageProvider: (any ReaderImageProvider)?

    public init(style: ReaderStyle, baseURL: URL? = nil, imageProvider: (any ReaderImageProvider)? = nil) {
        self.style = style
        self.baseURL = baseURL
        self.imageProvider = imageProvider
    }

    // MARK: - 入口

    public func render(_ blocks: [MarkdownBlock]) -> RenderedDocument {
        var state = State()
        renderBlocks(blocks, ctx: Context(), into: &state)
        // 去掉末尾多余的段落结束符
        if state.out.string.hasSuffix("\n") {
            state.out.deleteCharacters(in: NSRange(location: state.out.length - 1, length: 1))
        }
        return RenderedDocument(text: state.out, headings: state.headings)
    }

    // MARK: - 状态与上下文

    private struct State {
        var out = NSMutableAttributedString()
        var headings: [(id: String, location: Int)] = []
    }

    private struct Context {
        /// 外层嵌套的 NSTextBlock（引用、表格单元……），由外到内
        var textBlocks: [NSTextBlock] = []
        /// 列表缩进（相对于所在 block 的内容区）
        var indent: CGFloat = 0
        var listDepth = 0
        var color: NSColor = .labelColor
        /// 处在列表项内：块间距更紧
        var inList = false
    }

    // MARK: - 度量

    private var bodySize: CGFloat { style.fontSize }
    private var codeSize: CGFloat { (style.fontSize * 0.88).rounded() }
    private var blockGap: CGFloat { (style.fontSize * 0.8).rounded() }
    private var listGap: CGFloat { (style.fontSize * 0.3).rounded() }

    private func gap(_ ctx: Context) -> CGFloat { ctx.inList ? listGap : blockGap }

    // MARK: - 字体

    func bodyFont(size: CGFloat? = nil, weight: NSFont.Weight = .regular) -> NSFont {
        let size = size ?? bodySize
        switch style.fontFamily {
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
            // New York 不含中日韩字形；显式回退到宋体，避免系统回退字体的标点间距变宽
            let cjk = NSFontDescriptor(fontAttributes: [.family: "Songti SC"])
            let desc = serif.addingAttributes([.cascadeList: [cjk]])
            return NSFont(descriptor: desc, size: size) ?? base
        case .monospaced:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    func codeFont(size: CGFloat? = nil, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size ?? codeSize, weight: weight)
    }

    private func withTraits(_ font: NSFont, _ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let desc = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func headingFont(level: Int) -> NSFont {
        let scale: CGFloat
        let weight: NSFont.Weight
        switch level {
        case 1: scale = 1.8; weight = .bold
        case 2: scale = 1.45; weight = .semibold
        case 3: scale = 1.2; weight = .semibold
        case 4: scale = 1.05; weight = .semibold
        case 5: scale = 1.0; weight = .medium
        default: scale = 0.93; weight = .medium
        }
        return bodyFont(size: (bodySize * scale).rounded(), weight: weight)
    }

    // MARK: - 段落样式

    private func paragraphStyle(
        ctx: Context,
        firstLineIndent: CGFloat? = nil,
        headIndent: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        before: CGFloat = 0,
        after: CGFloat = 0,
        alignment: NSTextAlignment = .natural,
        extraBlocks: [NSTextBlock] = []
    ) -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.firstLineHeadIndent = firstLineIndent ?? ctx.indent
        p.headIndent = headIndent ?? ctx.indent
        p.lineHeightMultiple = lineHeight ?? style.lineHeight
        p.paragraphSpacingBefore = before
        p.paragraphSpacing = after
        p.alignment = alignment
        p.textBlocks = ctx.textBlocks + extraBlocks
        if let head = headIndent {
            p.tabStops = [NSTextTab(textAlignment: .left, location: head)]
            p.defaultTabInterval = 0
        }
        return p
    }

    // MARK: - 行内转换

    /// 把解析器产出的语义 AttributedString 转成带字体 / 颜色的 NSAttributedString
    private func inline(_ source: AttributedString, font: NSFont, color: NSColor) -> NSMutableAttributedString {
        let out = NSMutableAttributedString()
        for run in source.runs {
            let text = String(source.characters[run.range])
            let intent = run.inlinePresentationIntent ?? []
            var f = font
            if intent.contains(.code) {
                f = codeFont(size: (font.pointSize * 0.9).rounded(),
                             weight: font.fontDescriptor.symbolicTraits.contains(.bold) ? .semibold : .regular)
            }
            if intent.contains(.stronglyEmphasized) { f = withTraits(f, .bold) }
            if intent.contains(.emphasized) { f = withTraits(f, .italic) }

            var attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color]
            if intent.contains(.strikethrough) {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attrs[.foregroundColor] = NSColor.secondaryLabelColor
            }
            if let c = run.appKit.foregroundColor { attrs[.foregroundColor] = c }
            if let c = run.appKit.backgroundColor { attrs[.backgroundColor] = c }
            if let link = run.link { attrs[.link] = link }
            out.append(NSAttributedString(string: text, attributes: attrs))
        }
        return out
    }

    private func plain(_ s: String, font: NSFont, color: NSColor) -> NSMutableAttributedString {
        NSMutableAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    }

    /// 追加一个段落（自动补段落结束符并统一设置段落样式）
    private func emit(_ content: NSMutableAttributedString, paragraph: NSParagraphStyle, into state: inout State) {
        var terminator: [NSAttributedString.Key: Any] = [.font: bodyFont()]
        if content.length > 0 {
            // 只沿用字体（决定末行行高）；底色、链接等不能延伸到行尾
            terminator[.font] = content.attribute(.font, at: content.length - 1, effectiveRange: nil) ?? bodyFont()
        }
        content.append(NSAttributedString(string: "\n", attributes: terminator))
        content.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: content.length))
        state.out.append(content)
    }

    /// 给刚输出的最后一个段落补上块后间距（若它没有更深的 NSTextBlock —— 那种情况用 block 的 margin）
    private func ensureTrailingSpacing(_ spacing: CGFloat, ctx: Context, state: inout State) {
        let out = state.out
        guard out.length > 0 else { return }
        let lastIdx = out.length - 1
        guard let para = out.attribute(.paragraphStyle, at: lastIdx, effectiveRange: nil) as? NSParagraphStyle,
              para.textBlocks.count == ctx.textBlocks.count,
              para.paragraphSpacing < spacing else { return }
        let range = (out.string as NSString).paragraphRange(for: NSRange(location: lastIdx, length: 0))
        let updated = para.mutableCopy() as! NSMutableParagraphStyle
        updated.paragraphSpacing = spacing
        out.addAttribute(.paragraphStyle, value: updated, range: range)
    }

    // MARK: - NSTextBlock 工厂

    private func fullWidthBlock() -> NSTextBlock {
        let b = NSTextBlock()
        b.setValue(100, type: .percentageValueType, for: .width)
        return b
    }

    // MARK: - 块

    private func renderBlocks(_ blocks: [MarkdownBlock], ctx: Context, into state: inout State) {
        for block in blocks {
            renderBlock(block, ctx: ctx, into: &state)
            ensureTrailingSpacing(gap(ctx), ctx: ctx, state: &state)
        }
    }

    private func renderBlock(_ block: MarkdownBlock, ctx: Context, into state: inout State) {
        switch block {
        case .heading(let id, let level, _, let attributed):
            renderHeading(id: id, level: level, attributed: attributed, ctx: ctx, into: &state)

        case .paragraph(_, let attributed):
            let content = inline(attributed, font: bodyFont(), color: ctx.color)
            emit(content, paragraph: paragraphStyle(ctx: ctx), into: &state)

        case .codeBlock(_, _, _, let highlighted):
            renderCode(highlighted, ctx: ctx, into: &state)

        case .blockquote(_, let blocks):
            let quote = fullWidthBlock()
            quote.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
            quote.setBorderColor(NSColor.dynamic(.controlAccentColor, alpha: 0.7), for: .minX)
            quote.setWidth(14, type: .absoluteValueType, for: .padding, edge: .minX)
            quote.setWidth(2, type: .absoluteValueType, for: .padding, edge: .minY)
            quote.setWidth(2, type: .absoluteValueType, for: .padding, edge: .maxY)
            quote.setWidth(gap(ctx), type: .absoluteValueType, for: .margin, edge: .maxY)
            var inner = ctx
            inner.textBlocks.append(quote)
            inner.indent = 0
            inner.color = .secondaryLabelColor
            renderBlocks(blocks, ctx: inner, into: &state)
            // 引用内最后一段不留尾距，由 block margin 负责
            clearTrailingSpacing(in: &state)

        case .table(_, let headers, let alignments, let rows):
            renderTable(headers: headers, alignments: alignments, rows: rows, ctx: ctx, into: &state)

        case .unorderedList(_, let items):
            renderList(items, kind: .unordered, ctx: ctx, into: &state)
        case .orderedList(_, let start, let items):
            renderList(items, kind: .ordered(start), ctx: ctx, into: &state)
        case .taskList(_, let items):
            renderList(items, kind: .task, ctx: ctx, into: &state)

        case .thematicBreak:
            let rule = fullWidthBlock()
            rule.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
            rule.setBorderColor(Self.borderColor, for: .maxY)
            rule.setWidth(bodySize * 0.6, type: .absoluteValueType, for: .margin, edge: .minY)
            rule.setWidth(bodySize * 0.6, type: .absoluteValueType, for: .margin, edge: .maxY)
            let content = plain("\u{200B}", font: .systemFont(ofSize: 2), color: .clear)
            emit(content, paragraph: paragraphStyle(ctx: ctx, lineHeight: 1, extraBlocks: [rule]), into: &state)

        case .image(_, let source, let alt):
            renderImage(source: source, alt: alt, ctx: ctx, into: &state)

        case .html(_, let raw):
            let trimmed = raw.hasSuffix("\n") ? String(raw.dropLast()) : raw
            let content = plain(trimmed, font: codeFont(), color: .secondaryLabelColor)
            emit(content, paragraph: paragraphStyle(ctx: ctx, lineHeight: 1.25), into: &state)
        }
    }

    private func clearTrailingSpacing(in state: inout State) {
        let out = state.out
        guard out.length > 0,
              let para = out.attribute(.paragraphStyle, at: out.length - 1, effectiveRange: nil) as? NSParagraphStyle,
              para.paragraphSpacing > 0 else { return }
        let range = (out.string as NSString).paragraphRange(for: NSRange(location: out.length - 1, length: 0))
        let updated = para.mutableCopy() as! NSMutableParagraphStyle
        updated.paragraphSpacing = 0
        out.addAttribute(.paragraphStyle, value: updated, range: range)
    }

    // MARK: 标题

    private func renderHeading(id: String, level: Int, attributed: AttributedString, ctx: Context, into state: inout State) {
        let font = headingFont(level: level)
        let content = inline(attributed, font: font, color: ctx.color)
        let before = state.out.length == 0 ? 0 : (bodySize * (level <= 2 ? 1.3 : 0.9)).rounded()

        var extra: [NSTextBlock] = []
        var beforeSpacing = before
        if level <= 2 {
            // H1 / H2 下方一条细分隔线（NSTextBlock 下边框）
            let rule = fullWidthBlock()
            rule.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
            rule.setBorderColor(Self.borderColor, for: .maxY)
            rule.setWidth(bodySize * 0.3, type: .absoluteValueType, for: .padding, edge: .maxY)
            rule.setWidth(before, type: .absoluteValueType, for: .margin, edge: .minY)
            rule.setWidth(bodySize * 0.5, type: .absoluteValueType, for: .margin, edge: .maxY)
            extra = [rule]
            beforeSpacing = 0
        }

        state.headings.append((id: id, location: state.out.length))
        content.addAttribute(.mdHeadingID, value: id, range: NSRange(location: 0, length: content.length))
        emit(content, paragraph: paragraphStyle(ctx: ctx, lineHeight: 1.15, before: beforeSpacing,
                                                after: level <= 2 ? 0 : bodySize * 0.35,
                                                extraBlocks: extra),
             into: &state)
    }

    // MARK: 代码块

    /// NSTextBlock 画边框时不理会颜色的透明度，所以边框用不透明的灰
    static let borderColor = NSColor.dynamic(light: NSColor(white: 0.86, alpha: 1),
                                             dark: NSColor(white: 0.28, alpha: 1))

    static let codeBackground = NSColor.dynamic(light: NSColor(white: 0, alpha: 0.035),
                                                dark: NSColor(white: 1, alpha: 0.06))

    private func renderCode(_ highlighted: AttributedString, ctx: Context, into state: inout State) {
        let box = fullWidthBlock()
        box.backgroundColor = Self.codeBackground
        box.setWidth(0.5, type: .absoluteValueType, for: .border)
        box.setBorderColor(Self.borderColor)
        box.setWidth(12, type: .absoluteValueType, for: .padding)
        box.setWidth(gap(ctx), type: .absoluteValueType, for: .margin, edge: .maxY)

        var source = highlighted
        // 去掉末尾换行，避免块底多出空行
        while source.characters.last == "\n" {
            source.removeSubrange(source.index(beforeCharacter: source.endIndex)..<source.endIndex)
        }
        let content = inline(source, font: codeFont(), color: .labelColor)
        if content.length == 0 { content.append(plain(" ", font: codeFont(), color: .labelColor)) }
        // 代码块里关键字的「加粗」不要改字宽 —— 统一回等宽常规体
        content.enumerateAttribute(.font, in: NSRange(location: 0, length: content.length)) { value, range, _ in
            if let f = value as? NSFont, f.fontDescriptor.symbolicTraits.contains(.bold) {
                content.addAttribute(.font, value: codeFont(weight: .semibold), range: range)
            } else {
                content.addAttribute(.font, value: codeFont(), range: range)
            }
        }
        var inner = ctx
        inner.indent = 0
        emit(content, paragraph: paragraphStyle(ctx: inner, lineHeight: 1.2, extraBlocks: [box]), into: &state)
    }

    // MARK: 表格

    private func renderTable(headers: [AttributedString], alignments: [MarkdownTableAlignment],
                             rows: [[AttributedString]], ctx: Context, into state: inout State) {
        let columns = max(headers.count, rows.map(\.count).max() ?? 0)
        guard columns > 0 else { return }

        let table = NSTextTable()
        table.numberOfColumns = columns
        table.collapsesBorders = true
        table.hidesEmptyCells = false
        table.layoutAlgorithm = .automaticLayoutAlgorithm
        table.setValue(100, type: .percentageValueType, for: .width)
        table.setWidth(gap(ctx), type: .absoluteValueType, for: .margin, edge: .maxY)

        let cellFont = bodyFont(size: (bodySize * 0.93).rounded())
        let headerFont = withTraits(cellFont, .bold)
        let headerBG = NSColor.dynamic(.separatorColor, alpha: 0.18)
        let stripeBG = NSColor.dynamic(.separatorColor, alpha: 0.07)

        func alignment(_ col: Int) -> NSTextAlignment {
            guard col < alignments.count else { return .natural }
            switch alignments[col] {
            case .left, .none: return .natural
            case .center: return .center
            case .right: return .right
            }
        }

        let allRows = [headers] + rows
        for (r, row) in allRows.enumerated() {
            for c in 0..<columns {
                let cell = NSTextTableBlock(table: table, startingRow: r, rowSpan: 1, startingColumn: c, columnSpan: 1)
                cell.setWidth(0.5, type: .absoluteValueType, for: .border)
                cell.setBorderColor(Self.borderColor)
                cell.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minX)
                cell.setWidth(8, type: .absoluteValueType, for: .padding, edge: .maxX)
                cell.setWidth(4, type: .absoluteValueType, for: .padding, edge: .minY)
                cell.setWidth(4, type: .absoluteValueType, for: .padding, edge: .maxY)
                if r == 0 {
                    cell.backgroundColor = headerBG
                } else if r % 2 == 0 {
                    cell.backgroundColor = stripeBG
                }
                let text = c < row.count ? row[c] : AttributedString()
                let content = inline(text, font: r == 0 ? headerFont : cellFont, color: ctx.color)
                var inner = ctx
                inner.indent = 0
                emit(content, paragraph: paragraphStyle(ctx: inner, lineHeight: 1.2, alignment: alignment(c),
                                                        extraBlocks: [cell]),
                     into: &state)
            }
        }
    }

    // MARK: 列表

    private enum ListKind { case unordered, ordered(Int), task }

    private func renderList(_ items: [MarkdownListItem], kind: ListKind, ctx: Context, into state: inout State) {
        let markerFont = bodyFont()
        let markerWidth: CGFloat
        switch kind {
        case .ordered(let start):
            let digits = String(start + max(items.count - 1, 0)).count
            markerWidth = (bodySize * (0.9 + 0.6 * CGFloat(digits))).rounded()
        default:
            markerWidth = (bodySize * 1.5).rounded()
        }

        for (offset, item) in items.enumerated() {
            let marker: NSMutableAttributedString
            switch kind {
            case .unordered:
                let bullets = ["•", "◦", "▪︎"]
                marker = plain(bullets[ctx.listDepth % bullets.count] + "\t", font: markerFont, color: .secondaryLabelColor)
            case .ordered(let start):
                marker = plain("\(start + offset).\t", font: markerFont, color: .secondaryLabelColor)
            case .task:
                marker = checkbox(checked: item.checkbox ?? false, sourceLine: item.sourceLine, font: markerFont)
                marker.append(plain("\t", font: markerFont, color: .labelColor))
            }

            var inner = ctx
            inner.indent = ctx.indent + markerWidth
            inner.listDepth = ctx.listDepth + 1
            inner.inList = true

            var remaining = item.blocks[...]
            if case .paragraph(_, let attributed)? = remaining.first {
                // 首段与标记同行：首行从标记处开始，折行对齐到正文
                remaining = remaining.dropFirst()
                let content = marker
                content.append(inline(attributed, font: bodyFont(), color: ctx.color))
                emit(content, paragraph: paragraphStyle(ctx: ctx, firstLineIndent: ctx.indent,
                                                        headIndent: inner.indent,
                                                        after: listGap),
                     into: &state)
            } else {
                emit(marker, paragraph: paragraphStyle(ctx: ctx, firstLineIndent: ctx.indent,
                                                       headIndent: inner.indent, after: 0),
                     into: &state)
            }
            for block in remaining {
                renderBlock(block, ctx: inner, into: &state)
                ensureTrailingSpacing(listGap, ctx: inner, state: &state)
            }
        }
    }

    private func checkbox(checked: Bool, sourceLine: Int?, font: NSFont) -> NSMutableAttributedString {
        let attachment = NSTextAttachment()
        let symbol = checked ? "checkmark.square.fill" : "square"
        let desc = checked ? L.taskDone : L.taskTodo
        let config = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .medium)
            .applying(.init(paletteColors: [checked ? .controlAccentColor : .secondaryLabelColor]))
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: desc)?
            .withSymbolConfiguration(config) {
            attachment.image = image
            let size = image.size
            attachment.bounds = NSRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
        }
        let s = NSMutableAttributedString(attachment: attachment)
        let range = NSRange(location: 0, length: s.length)
        s.addAttribute(.font, value: font, range: range)
        s.addAttribute(.mdTaskChecked, value: checked, range: range)
        if let sourceLine {
            s.addAttribute(.mdTaskSourceLine, value: sourceLine, range: range)
            s.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
        }
        s.addAttribute(.toolTip, value: desc, range: range)
        return s
    }

    // MARK: 图片

    func resolveImageURL(_ source: String?) -> URL? {
        guard let source, !source.isEmpty else { return nil }
        if let url = URL(string: source), let scheme = url.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme) {
            return url
        }
        let path = source.removingPercentEncoding ?? source
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        if let base = baseURL { return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL }
        return nil
    }

    private func renderImage(source: String?, alt: String, ctx: Context, into state: inout State) {
        let url = resolveImageURL(source)
        var image: NSImage?
        var failure: String?
        if let url {
            if url.isFileURL {
                image = NSImage(contentsOf: url)
                if image == nil { failure = L.imageCannotLoad }
            } else {
                image = imageProvider?.image(for: url)
                if image == nil {
                    let failed = imageProvider.map { $0.hasFailed(url) } ?? true
                    failure = failed ? L.imageLoadFailed : L.imageLoading
                }
            }
        } else {
            failure = L.imageInvalidPath
        }

        let para = paragraphStyle(ctx: ctx, lineHeight: 1)
        if let image {
            let attachment = FittingImageAttachment()
            attachment.image = image
            let content = NSMutableAttributedString(attachment: attachment)
            if !alt.isEmpty {
                content.addAttribute(.toolTip, value: alt, range: NSRange(location: 0, length: content.length))
            }
            emit(content, paragraph: para, into: &state)
            if !alt.isEmpty {
                let caption = plain(alt, font: bodyFont(size: (bodySize * 0.8).rounded()), color: .secondaryLabelColor)
                emit(caption, paragraph: paragraphStyle(ctx: ctx, before: 4), into: &state)
            }
        } else {
            let content = plain("🖼 " + L.imagePlaceholder(failure ?? L.imageLoadFailed, alt: alt),
                                font: bodyFont(size: (bodySize * 0.85).rounded()), color: .secondaryLabelColor)
            emit(content, paragraph: paragraphStyle(ctx: ctx), into: &state)
        }
    }
}

extension NSColor {
    /// 带透明度的动态色。直接对系统色调 `withAlphaComponent` 会按**当前**外观定死，
    /// 切换深浅色后不跟着变；包一层 provider 让它在绘制时再解析。
    static func dynamic(_ base: NSColor, alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { _ in base.withAlphaComponent(alpha) }
    }

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

/// 图片附件：宽度超过行宽时等比缩小，窗口变窄也跟着缩
final class FittingImageAttachment: NSTextAttachment {
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: NSRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> NSRect {
        guard let size = image?.size, size.width > 0, size.height > 0 else {
            return super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag,
                                          glyphPosition: position, characterIndex: charIndex)
        }
        let maxWidth = max(40, lineFrag.width - 4)
        let scale = min(1, maxWidth / size.width)
        return NSRect(x: 0, y: 0, width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }
}
