import SwiftUI
import AppKit

/// 主文档交互视图（NavigationSplitView 大纲侧边栏 + 阅读器 / 编辑器 + 悬浮状态条）
public struct MainDocumentView: View {
    @Binding public var document: MarkdownDocument
    public var fileURL: URL?

    @StateObject private var state = EditorState()
    @State private var parsedDoc = ParsedDocument()
    @State private var parseTask: Task<Void, Never>?

    public init(document: Binding<MarkdownDocument>, fileURL: URL? = nil) {
        self._document = document
        self.fileURL = fileURL
    }

    private var documentTitle: String {
        if let name = fileURL?.lastPathComponent, !name.isEmpty { return name }
        if let firstHeading = parsedDoc.tocItems.first?.title, !firstHeading.isEmpty { return firstHeading }
        return "未命名.md"
    }

    private var baseURL: URL? {
        fileURL?.deletingLastPathComponent()
    }

    private var splitVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { state.showTOC ? .all : .detailOnly },
            set: { state.showTOC = ($0 != .detailOnly) }
        )
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: splitVisibility) {
            TOCSidebarView(
                items: parsedDoc.tocItems,
                targetScrollId: $state.targetScrollId,
                activeId: state.activeHeadingId
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                FloatingStatusCapsule(stats: parsedDoc.stats)
            }
            .navigationTitle(documentTitle)
            .toolbar { NativeUnifiedToolbar(state: state) }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.editorState, state)
        .onAppear { scheduleParse(text: document.text, immediate: true) }
        .onChange(of: document.text) { _, newText in
            scheduleParse(text: newText, immediate: false)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { @MainActor in
                        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                    }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        switch state.viewMode {
        case .reading:
            reader
        case .editing:
            NativeEditorView(text: $document.text)
        case .split:
            HSplitView {
                NativeEditorView(text: $document.text).frame(minWidth: 320)
                reader.frame(minWidth: 320)
            }
        }
    }

    private var reader: some View {
        NativeReaderView(
            parsedDoc: parsedDoc,
            targetScrollId: $state.targetScrollId,
            activeHeadingId: $state.activeHeadingId,
            baseURL: baseURL,
            onToggleTask: { line, checked in
                Task { @MainActor in toggleTask(sourceLine: line, newChecked: checked) }
            }
        )
    }

    // MARK: - 解析（250ms 防抖；大文档后台解析）

    private func scheduleParse(text: String, immediate: Bool) {
        parseTask?.cancel()

        // 小文档或首次加载：同步解析（命中缓存时几乎零成本）
        if immediate || text.utf8.count < 2048 {
            parsedDoc = MarkdownASTParser.parse(markdown: text)
            return
        }

        // 大文档：250ms 防抖 + 后台线程解析
        parseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            let result = await Task.detached(priority: .userInitiated) {
                MarkdownASTParser.parse(markdown: text)
            }.value
            if !Task.isCancelled {
                parsedDoc = result
            }
        }
    }

    // MARK: - 任务列表勾选回写

    private func toggleTask(sourceLine: Int, newChecked: Bool) {
        var lines = document.text.components(separatedBy: "\n")
        guard lines.indices.contains(sourceLine) else { return }

        let original = lines[sourceLine]
        guard let range = original.range(of: #"\[[ xX]\]"#, options: .regularExpression) else { return }
        lines[sourceLine] = original.replacingCharacters(in: range, with: newChecked ? "[x]" : "[ ]")

        let updated = lines.joined(separator: "\n")
        if updated != document.text {
            document.text = updated
        }
    }
}
