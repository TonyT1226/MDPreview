import SwiftUI
import AppKit

/// 主文档交互视图（NavigationSplitView 大纲侧边栏 + 阅读器 / 编辑器 + 悬浮状态条）
public struct MainDocumentView: View {
    @Binding public var document: MarkdownDocument
    public var fileURL: URL?

    @StateObject private var state = EditorState()
    @State private var parsedDoc = ParsedDocument()
    @State private var parseTask: Task<Void, Never>?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // 外部修改热重载
    @State private var monitor: FileMonitor?
    @State private var lastDiskText: String = ""
    @State private var conflictDiskText: String?
    @State private var showConflict = false
    @State private var fileMissing = false

    public init(document: Binding<MarkdownDocument>, fileURL: URL? = nil) {
        self._document = document
        self.fileURL = fileURL
    }

    private var documentTitle: String {
        if let name = fileURL?.lastPathComponent, !name.isEmpty { return name }
        if let firstHeading = parsedDoc.tocItems.first?.title, !firstHeading.isEmpty { return firstHeading }
        return L.untitledDocument
    }

    private var baseURL: URL? {
        fileURL?.deletingLastPathComponent()
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TOCSidebarView(
                items: parsedDoc.tocItems,
                targetScrollId: $state.targetScrollId,
                activeId: state.activeHeadingId
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if fileMissing { fileMissingBanner }
                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                FloatingStatusCapsule(stats: parsedDoc.stats)
            }
            .navigationTitle(documentTitle)
            .toolbar { NativeUnifiedToolbar(state: state) }
            .confirmationDialog(L.externalChangeTitle, isPresented: $showConflict, titleVisibility: .visible) {
                Button(L.useDiskVersion) {
                    if let disk = conflictDiskText {
                        document.text = disk
                        lastDiskText = disk
                    }
                    conflictDiskText = nil
                }
                Button(L.keepMyChanges, role: .cancel) {
                    lastDiskText = conflictDiskText ?? lastDiskText
                    conflictDiskText = nil
                }
            } message: {
                Text(L.externalChangeMessage)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.editorState, state)
        .focusedSceneValue(\.printableDocument, PrintableDocument(
            parsed: parsedDoc,
            title: documentTitle,
            baseURL: baseURL
        ))
        .onAppear { scheduleParse(text: document.text, immediate: true) }
        .onChange(of: fileURL, initial: true) { _, url in
            setupMonitor(for: url)
        }
        .onDisappear {
            monitor?.stop()
            monitor = nil
        }
        .onChange(of: document.text) { _, newText in
            scheduleParse(text: newText, immediate: false)
        }
        // 侧边栏可见性与 EditorState 双向同步（放在 onChange 里改，避免在视图更新中发布状态）
        .onChange(of: state.showTOC) { _, show in
            let target: NavigationSplitViewVisibility = show ? .all : .detailOnly
            if columnVisibility != target { columnVisibility = target }
        }
        .onChange(of: columnVisibility) { _, vis in
            let show = (vis != .detailOnly)
            if state.showTOC != show { state.showTOC = show }
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
            editor
        case .split:
            HSplitView {
                editor.frame(minWidth: 320)
                reader.frame(minWidth: 320)
            }
        }
    }

    private var editor: some View {
        NativeEditorView(text: $document.text)
    }

    private var fileMissingBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(L.fileDeletedOnDisk)
                .font(.system(size: 12))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - 外部修改热重载

    private func setupMonitor(for url: URL?) {
        monitor?.stop()
        monitor = nil
        fileMissing = false
        guard let url else { return }
        lastDiskText = document.text
        monitor = FileMonitor(url: url) { event in
            handleFileEvent(event)
        }
    }

    private func handleFileEvent(_ event: FileMonitor.Event) {
        switch event {
        case .deleted:
            fileMissing = true
        case .modified:
            fileMissing = false
            guard let url = fileURL, let disk = FileMonitor.readText(at: url) else { return }
            if disk == document.text {
                lastDiskText = disk
                return
            }
            if document.text == lastDiskText {
                // 本地无改动 —— 静默重载
                document.text = disk
                lastDiskText = disk
            } else {
                // 本地 + 外部都改了 —— 让用户选
                conflictDiskText = disk
                showConflict = true
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
