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

            CommandMenu(L.menuView) {
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
    }
}
