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
        ThemeController.shared.start()
    }
}

@main
struct MDPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.editorState) private var editorState: EditorState?
    @FocusedValue(\.printableDocument) private var printable: PrintableDocument?

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

            // 并进系统自带的「显示 / View」菜单，不再另开一个同名菜单
            CommandGroup(before: .sidebar) {
                Button(L.readingMode) { editorState?.setViewMode(.reading) }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(editorState == nil)
                Button(L.editingMode) { editorState?.setViewMode(.editing) }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(editorState == nil)
                Button(L.splitMode) { editorState?.setViewMode(.split) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(editorState == nil)

                Divider()

                Button((editorState?.showTOC ?? true) ? L.hideOutline : L.showOutline) {
                    editorState?.toggleTOC()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(editorState == nil)

                Divider()

                Button(L.zoomIn) { FontZoom.increase() }
                    .keyboardShortcut("=", modifiers: .command)
                Button(L.zoomOut) { FontZoom.decrease() }
                    .keyboardShortcut("-", modifiers: .command)
                Button(L.actualSize) { FontZoom.reset() }
                    .keyboardShortcut("0", modifiers: .command)

                Divider()
            }

            CommandGroup(replacing: .printItem) {
                Button(L.printDocument) {
                    if let printable { DocumentPrinter.runPrintPanel(printable) }
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(printable == nil)

                Button(L.exportPDF) {
                    if let printable { DocumentPrinter.exportPDF(printable) }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(printable == nil)
            }
        }

        Settings {
            PreferencesView()
        }
    }
}
