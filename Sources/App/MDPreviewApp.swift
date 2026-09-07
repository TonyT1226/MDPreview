import SwiftUI
import AppKit
import MDPreviewCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        MarkdownASTParser.prewarm()
    }
}

@main
struct MDPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.editorState) private var editorState: EditorState?

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            MainDocumentView(document: file.$document, fileURL: file.fileURL)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            TextEditingCommands()

            CommandMenu("视图") {
                Button("阅读模式") { editorState?.setViewMode(.reading) }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(editorState == nil)
                Button("编辑模式") { editorState?.setViewMode(.editing) }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(editorState == nil)
                Button("分屏模式") { editorState?.setViewMode(.split) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(editorState == nil)

                Divider()

                Button((editorState?.showTOC ?? true) ? "隐藏目录大纲" : "显示目录大纲") {
                    editorState?.toggleTOC()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(editorState == nil)
            }
        }
    }
}
