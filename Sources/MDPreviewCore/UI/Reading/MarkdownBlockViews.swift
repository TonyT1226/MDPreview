import SwiftUI
import AppKit

// MARK: - 标题组件 (Heading)
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
                .font(fontForLevel(level))
                .fontWeight(weightForLevel(level))
                .foregroundColor(.primary)
                .padding(.top, topPaddingForLevel(level))

            if level == 1 || level == 2 {
                Divider()
                    .opacity(0.4)
                    .padding(.bottom, 4)
            }
        }
        .id(id)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 26, design: .default)
        case 2: return .system(size: 21, design: .default)
        case 3: return .system(size: 17, design: .default)
        case 4: return .system(size: 15, design: .default)
        case 5: return .system(size: 14, design: .default)
        default: return .system(size: 13, design: .default)
        }
    }

    private func weightForLevel(_ level: Int) -> Font.Weight {
        switch level {
        case 1: return .bold
        case 2: return .semibold
        case 3: return .medium
        default: return .regular
        }
    }

    private func topPaddingForLevel(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 20
        case 2: return 16
        case 3: return 12
        default: return 8
        }
    }
}

// MARK: - 段落组件 (Paragraph)
public struct ParagraphBlockView: View {
    public let attributed: AttributedString

    public init(attributed: AttributedString) {
        self.attributed = attributed
    }

    public var body: some View {
        Text(attributed)
            .font(.system(size: 14, weight: .regular, design: .default))
            .lineSpacing(5)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 代码块组件 (Code Block)
public struct CodeBlockView: View {
    public let id: String
    public let language: String?
    public let code: String
    public let highlighted: AttributedString
    
    @State private var isCopied: Bool = false

    public init(id: String, language: String?, code: String, highlighted: AttributedString) {
        self.id = id
        self.language = language
        self.code = code
        self.highlighted = highlighted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部小横条 (语言标签与复制按钮)
            HStack {
                if let lang = language, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("CODE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(isCopied ? "已复制" : "复制")
                            .font(.system(size: 11, weight: .medium))
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

            // 代码文本区
            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlighted)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - 表格组件 (Table)
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
                // 表头
                GridRow {
                    ForEach(0..<headers.count, id: \.self) { idx in
                        Text(headers[idx])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: frameAlignment(at: idx))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                    }
                }
                .background(Color(nsColor: .separatorColor).opacity(0.2))

                Divider().opacity(0.4)

                // 行
                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    let row = rows[rowIdx]
                    GridRow {
                        ForEach(0..<row.count, id: \.self) { colIdx in
                            Text(row[colIdx])
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: frameAlignment(at: colIdx))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                        }
                    }
                    .background(rowIdx % 2 == 1 ? Color(nsColor: .separatorColor).opacity(0.08) : Color.clear)
                }
            }
            .padding(1)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
            )
        }
        .padding(.vertical, 6)
    }

    private func frameAlignment(at index: Int) -> Alignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .none: return .leading
        }
    }
}

// MARK: - 引用组件 (Blockquote)
public struct BlockquoteBlockView: View {
    public let blocks: [MarkdownBlock]

    public init(blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 3.5)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(blocks) { block in
                    MarkdownBlockDispatcher(block: block)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
    }
}

// MARK: - 任务列表组件 (Task List)
public struct TaskListBlockView: View {
    @State public var items: [MarkdownTaskItem]

    public init(items: [MarkdownTaskItem]) {
        self._items = State(initialValue: items)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<items.count, id: \.self) { idx in
                HStack(alignment: .top, spacing: 8) {
                    Button(action: {
                        items[idx].isChecked.toggle()
                    }) {
                        Image(systemName: items[idx].isChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(items[idx].isChecked ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    Text(items[idx].attributedText)
                        .font(.system(size: 14, design: .default))
                        .foregroundColor(items[idx].isChecked ? .secondary : .primary)
                        .strikethrough(items[idx].isChecked, color: .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 统一分发器 (Dispatcher)
public struct MarkdownBlockDispatcher: View {
    public let block: MarkdownBlock

    public init(block: MarkdownBlock) {
        self.block = block
    }

    public var body: some View {
        switch block {
        case .heading(let id, let level, let text, let attributed):
            HeadingBlockView(id: id, level: level, text: text, attributed: attributed)

        case .paragraph(let attributed):
            ParagraphBlockView(attributed: attributed)

        case .codeBlock(let id, let language, let code, let highlighted):
            CodeBlockView(id: id, language: language, code: code, highlighted: highlighted)

        case .blockquote(let blocks):
            BlockquoteBlockView(blocks: blocks)

        case .table(let headers, let alignments, let rows):
            TableBlockView(headers: headers, alignments: alignments, rows: rows)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<items.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(items[idx])
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, 2)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<items.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(items[idx].number).")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 20, alignment: .trailing)
                        Text(items[idx].text)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, 2)

        case .taskList(let items):
            TaskListBlockView(items: items)

        case .thematicBreak:
            Divider()
                .padding(.vertical, 8)

        case .html(let raw):
            Text(raw)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
