import SwiftUI

/// 遵循 macOS 27+ HIG 与 Liquid Glass 的统一原生工具栏 (极简无重复中心栏)
public struct LiquidGlassToolbar: ToolbarContent {
    @ObservedObject var state: EditorState
    var documentTitle: String
    var onExportPDF: () -> Void

    public init(
        state: EditorState,
        documentTitle: String = "未命名.md",
        onExportPDF: @escaping () -> Void = {}
    ) {
        self.state = state
        self.documentTitle = documentTitle
        self.onExportPDF = onExportPDF
    }

    public var body: some ToolbarContent {
        // 左侧：大纲侧边栏开关 + 文件名称显示 (类似 Preview.app)
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(.smooth(duration: 0.28)) {
                        state.showTOC.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(state.showTOC ? .accentColor : .primary)
                }
                .help("切换目录大纲 (⌘⌥S)")

                Text(documentTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(documentTitle)
            }
        }

        // 右侧功能组：三种模式切换与导出 (附带原生快捷键提示)
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state.viewMode = .reading
                    }
                }) {
                    Label("阅读模式", systemImage: "book.pages")
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state.viewMode = .editing
                    }
                }) {
                    Label("编辑模式", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state.viewMode = .split
                    }
                }) {
                    Label("分屏模式", systemImage: "rectangle.split.2x1")
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Divider()

                Button(action: onExportPDF) {
                    Label("打印 / 导出 PDF...", systemImage: "printer")
                }
                .keyboardShortcut("p", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .help("视图模式与选项")
        }
    }
}
