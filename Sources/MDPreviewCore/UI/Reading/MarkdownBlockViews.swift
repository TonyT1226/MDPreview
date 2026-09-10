import SwiftUI
import AppKit

// MARK: - 渲染上下文（图片 baseURL、任务回写回调，经 Environment 下传）

public struct MarkdownRenderContext: Sendable, Equatable {
    public var baseURL: URL?
    public var onToggleTask: @Sendable (_ sourceLine: Int, _ newChecked: Bool) -> Void

    public init(baseURL: URL? = nil,
                onToggleTask: @escaping @Sendable (Int, Bool) -> Void = { _, _ in }) {
        self.baseURL = baseURL
        self.onToggleTask = onToggleTask
    }

    // 闭包不参与相等性 —— 只看 baseURL。让 SwiftUI 能跳过等值的环境写入，
    // 避免每次 body 重建 context 就让整棵块视图树失效（并触发 HeadingOffsetsKey 抖动）。
    public static func == (lhs: MarkdownRenderContext, rhs: MarkdownRenderContext) -> Bool {
        lhs.baseURL == rhs.baseURL
    }
}

private struct MarkdownRenderContextKey: EnvironmentKey {
    static let defaultValue = MarkdownRenderContext()
}

public extension EnvironmentValues {
    var markdownContext: MarkdownRenderContext {
        get { self[MarkdownRenderContextKey.self] }
        set { self[MarkdownRenderContextKey.self] = newValue }
    }
}

/// 滚动联动：收集各标题在阅读容器坐标系里的 y 位置
public struct HeadingOffsetsKey: PreferenceKey {
    public static let defaultValue: [String: CGFloat] = [:]
    public static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - 标题

public struct HeadingBlockView: View {
    public let id: String
    public let level: Int
    public let text: String
    public let attributed: AttributedString

    public init(id: String, level: Int, text: String, attributed: AttributedString) {
        self.id = id
        self.level = level
        self.text = text
        self.attributed = attributed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(attributed)
                .foregroundColor(.primary)
                .padding(.top, topPadding)
                .fixedSize(horizontal: false, vertical: true)

            if level == 1 || level == 2 {
                Divider().opacity(0.4).padding(.bottom, 4)
            }
        }
        .id(id)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeadingOffsetsKey.self,
                    // 量化到 2pt —— 亚像素抖动不再算「值变了」，压掉
                    // "preference tried to update multiple times per frame"
                    value: [id: (geo.frame(in: .named("reader")).minY / 2).rounded() * 2]
                )
            }
        )
    }

    private var topPadding: CGFloat {
        switch level {
        case 1: return 20
        case 2: return 16
        case 3: return 12
        default: return 8
        }
    }
}

// MARK: - 段落

public struct ParagraphBlockView: View {
    public let attributed: AttributedString
    public init(attributed: AttributedString) { self.attributed = attributed }

    public var body: some View {
        Text(attributed)
            .font(.system(size: 14, weight: .regular, design: .default))
            .lineSpacing(5)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 图片

public struct MarkdownImageView: View {
    public let source: String?
    public let alt: String
    @Environment(\.markdownContext) private var context

    public init(source: String?, alt: String) {
        self.source = source
        self.alt = alt
    }

    private var resolvedURL: URL? {
        guard let source, !source.isEmpty else { return nil }
        if let url = URL(string: source), url.scheme == "http" || url.scheme == "https" || url.scheme == "file" {
            return url
        }
        if let base = context.baseURL {
            return URL(fileURLWithPath: source, relativeTo: base)
        }
        return nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            if !alt.isEmpty {
                Text(alt)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let url = resolvedURL, url.isFileURL {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                placeholder(L.imageCannotLoad)
            }
        } else if let url = resolvedURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().frame(maxWidth: .infinity, alignment: .leading)
                case .failure:
                    placeholder(L.imageLoadFailed)
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 60)
                @unknown default:
                    placeholder(L.imageGenericAlt)
                }
            }
        } else {
            placeholder(L.imageInvalidPath)
        }
    }

    private func placeholder(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
            Text(L.imagePlaceholder(message, alt: alt)).font(.system(size: 12))
        }
        .foregroundColor(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .separatorColor).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 代码块

public struct CodeBlockView: View {
    public let id: String
    public let language: String?
    public let code: String
    public let highlighted: AttributedString

    @State private var isCopied = false

    public init(id: String, language: String?, code: String, highlighted: AttributedString) {
        self.id = id
        self.language = language
        self.code = code
        self.highlighted = highlighted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text((language?.isEmpty == false ? language! : "code").uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(isCopied ? L.copied : L.copy).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isCopied ? .green : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .separatorColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider().opacity(0.2)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlighted)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .textSelection(.enabled)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5))
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { isCopied = false }
        }
    }
}

// MARK: - 表格

public struct TableBlockView: View {
    public let headers: [AttributedString]
    public let alignments: [MarkdownTableAlignment]
    public let rows: [[AttributedString]]

    public init(headers: [AttributedString], alignments: [MarkdownTableAlignment], rows: [[AttributedString]]) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    ForEach(0..<headers.count, id: \.self) { idx in
                        Text(headers[idx])
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: frameAlignment(at: idx))
                            .padding(.vertical, 6).padding(.horizontal, 8)
                    }
                }
                .background(Color(nsColor: .separatorColor).opacity(0.2))

                Divider().opacity(0.4)

                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    GridRow {
                        ForEach(0..<rows[rowIdx].count, id: \.self) { colIdx in
                            Text(rows[rowIdx][colIdx])
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: frameAlignment(at: colIdx))
                                .padding(.vertical, 5).padding(.horizontal, 8)
                        }
                    }
                    .background(rowIdx % 2 == 1 ? Color(nsColor: .separatorColor).opacity(0.08) : Color.clear)
                }
            }
            .padding(1)
            .background(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5))
        }
        .padding(.vertical, 6)
    }

    private func frameAlignment(at index: Int) -> Alignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

// MARK: - 引用

public struct BlockquoteBlockView: View {
    public let blocks: [MarkdownBlock]
    public init(blocks: [MarkdownBlock]) { self.blocks = blocks }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 3.5)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(blocks) { MarkdownBlockDispatcher(block: $0) }
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
    }
}

// MARK: - 列表（无序 / 有序 / 任务，支持嵌套子块）

public struct ListBlockView: View {
    public enum Kind { case unordered, ordered(start: Int), task }
    public let kind: Kind
    public let items: [MarkdownListItem]
    @Environment(\.markdownContext) private var context

    public init(kind: Kind, items: [MarkdownListItem]) {
        self.kind = kind
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                HStack(alignment: .top, spacing: 8) {
                    marker(for: item, at: offset)
                        .frame(minWidth: 18, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.blocks) { MarkdownBlockDispatcher(block: $0) }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func marker(for item: MarkdownListItem, at offset: Int) -> some View {
        switch kind {
        case .unordered:
            Text("•").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
        case .ordered(let start):
            Text("\(start + offset).")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        case .task:
            Button {
                if let line = item.sourceLine {
                    context.onToggleTask(line, !(item.checkbox ?? false))
                }
            } label: {
                Image(systemName: (item.checkbox ?? false) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor((item.checkbox ?? false) ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(item.sourceLine == nil)
        }
    }
}

// MARK: - 分发器

public struct MarkdownBlockDispatcher: View {
    public let block: MarkdownBlock
    public init(block: MarkdownBlock) { self.block = block }

    public var body: some View {
        switch block {
        case .heading(let id, let level, let text, let attributed):
            HeadingBlockView(id: id, level: level, text: text, attributed: attributed)
        case .paragraph(_, let attributed):
            ParagraphBlockView(attributed: attributed)
        case .image(_, let source, let alt):
            MarkdownImageView(source: source, alt: alt)
        case .codeBlock(let id, let language, let code, let highlighted):
            CodeBlockView(id: id, language: language, code: code, highlighted: highlighted)
        case .blockquote(_, let blocks):
            BlockquoteBlockView(blocks: blocks)
        case .table(_, let headers, let alignments, let rows):
            TableBlockView(headers: headers, alignments: alignments, rows: rows)
        case .unorderedList(_, let items):
            ListBlockView(kind: .unordered, items: items)
        case .orderedList(_, let start, let items):
            ListBlockView(kind: .ordered(start: start), items: items)
        case .taskList(_, let items):
            ListBlockView(kind: .task, items: items)
        case .thematicBreak:
            Divider().padding(.vertical, 8)
        case .html(_, let raw):
            Text(raw)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
