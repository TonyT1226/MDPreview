import SwiftUI
import AppKit

/// 主文档交互视图 (整合 NavigationSplitView 大纲侧边栏、阅读器、编辑器与悬浮状态条，支持多窗口/多标签)
public struct MainDocumentView: View {
    @Binding public var document: MarkdownDocument
    public var fileURL: URL?
    @StateObject private var state = EditorState()
    @State private var parsedDoc: ParsedDocument = ParsedDocument()
    @State private var parseTask: Task<Void, Never>? = nil

    public init(document: Binding<MarkdownDocument>, fileURL: URL? = nil) {
        self._document = document
        self.fileURL = fileURL
    }

    /// 文档标题（优先取已打开文件名，否则取首个 H1，否则显示默认名称）
    private var documentTitle: String {
        if let name = fileURL?.lastPathComponent, !name.isEmpty {
            return name
        }
        if let firstHeading = parsedDoc.tocItems.first?.title, !firstHeading.isEmpty {
            return firstHeading
        }
        return "未命名.md"
    }

    private var splitVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { state.showTOC ? .all : .detailOnly },
            set: { state.showTOC = ($0 != .detailOnly) }
        )
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: splitVisibility) {
            // 1. 左侧原生分栏大纲侧边栏
            TOCSidebarView(items: parsedDoc.tocItems, targetScrollId: $state.targetScrollId)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            // 2. 主区域：根据模式展示
            ZStack(alignment: .bottomTrailing) {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 悬浮状态胶囊 (macOS 27 风格，字数与行数)
                FloatingStatusCapsule(stats: parsedDoc.stats)
            }
            .navigationTitle(documentTitle)
            .toolbar {
                NativeUnifiedToolbar(state: state)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            updateParsedDoc(text: document.text)
        }
        .onChange(of: document.text) { _, newText in
            updateParsedDoc(text: newText)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task { @MainActor in
                        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                    }
                }
            }
            return true
        }
        // 快捷键映射支持
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .reading
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .editing
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .split
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.smooth(duration: 0.28)) {
                    state.showTOC.toggle()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .opacity(0)
        )
    }

    @ViewBuilder
    private var mainContentView: some View {
        switch state.viewMode {
        case .reading:
            NativeReaderView(parsedDoc: parsedDoc, targetScrollId: $state.targetScrollId)
        case .editing:
            NativeEditorView(text: $document.text) { newText in
                updateParsedDoc(text: newText)
            }
        case .split:
            HSplitView {
                NativeEditorView(text: $document.text) { newText in
                    updateParsedDoc(text: newText)
                }
                .frame(minWidth: 320)

                NativeReaderView(parsedDoc: parsedDoc, targetScrollId: $state.targetScrollId)
                    .frame(minWidth: 320)
            }
        }
    }

    private func updateParsedDoc(text: String) {
        if text.count < 6000 {
            self.parsedDoc = MarkdownASTParser.parse(markdown: text)
        } else {
            parseTask?.cancel()
            parseTask = Task.detached(priority: .userInitiated) {
                let result = MarkdownASTParser.parse(markdown: text)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.parsedDoc = result
                }
            }
        }
    }

    private func handlePrint() {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36

        let printView = NSHostingView(
            rootView: NativeReaderView(parsedDoc: parsedDoc, targetScrollId: .constant(nil))
                .frame(width: 595.28) // 标准 A4 宽度 (pt)
        )
        printView.layout()

        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}

#if DEBUG
struct MainDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        MainDocumentView(document: .constant(MarkdownDocument(text: "# 示例文档\n\n这是预览内容。\n\n## 第二节\n\n段落文字。")))
            .frame(width: 900, height: 600)
    }
}
#endif
