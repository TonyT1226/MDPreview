import SwiftUI
import AppKit

/// 主文档交互视图 (整合大纲侧边栏、阅读器、编辑器与悬浮状态条)
public struct MainDocumentView: View {
    @Binding public var document: MarkdownDocument
    @StateObject private var state = EditorState()
    @State private var parsedDoc: ParsedDocument = ParsedDocument()
    @State private var parseTask: Task<Void, Never>? = nil

    public init(document: Binding<MarkdownDocument>) {
        self._document = document
    }

    /// 文档标题（优先取首个 H1，否则显示默认名称）
    private var documentTitle: String {
        if let firstHeading = parsedDoc.tocItems.first?.title, !firstHeading.isEmpty {
            return firstHeading
        }
        return "未命名.md"
    }

    public var body: some View {
        HStack(spacing: 0) {
            // 1. 左侧大纲侧边栏 (流体展开/折叠)
            if state.showTOC {
                TOCSidebarView(items: parsedDoc.tocItems, targetScrollId: $state.targetScrollId)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                Divider()
                    .opacity(0.3)
                    .transition(.opacity)
            }

            // 2. 主区域：根据模式展示
            ZStack(alignment: .bottomTrailing) {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 悬浮状态胶囊 (macOS 27 风格，字数与行数)
                FloatingStatusCapsule(stats: parsedDoc.stats)
            }
        }
        .animation(.smooth(duration: 0.28), value: state.showTOC)
        .toolbar {
            LiquidGlassToolbar(
                state: state,
                documentTitle: documentTitle,
                onExportPDF: handlePrint
            )
        }
        .onAppear {
            updateParsedDoc(text: document.text)
        }
        .onChange(of: document.text) { _, newText in
            updateParsedDoc(text: newText)
        }
        // 快捷键映射支持
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.toggleViewMode()
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .reading
                }
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .editing
                }
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
            .opacity(0)
        )
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.viewMode = .split
                }
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
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
