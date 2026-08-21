import SwiftUI
import AppKit
import MDPreviewCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 设置为标准 GUI 前台应用并置顶激活
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // 2. 异步预热底层解析器与加载应用图标
        MarkdownASTParser.prewarm()
        setupAppIconAsync()

        // 3. 命令行参数检查 (如终端执行: swift run MDPreview SampleDocument.md)
        let args = CommandLine.arguments
        if args.count > 1 {
            let filePath = args[1]
            let fileURL = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                DocumentStore.shared.load(from: fileURL)
                return
            }
        }
    }

    /// Finder 双击 .md 或拖拽到 Dock 图标时自动响应打开
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        DocumentStore.shared.load(from: url)
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        if let first = filenames.first {
            let url = URL(fileURLWithPath: first)
            DocumentStore.shared.load(from: url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    private func setupAppIconAsync() {
        Task.detached(priority: .background) {
            let possiblePaths = [
                "Resources/AppIcon.png",
                "../Resources/AppIcon.png",
                Bundle.main.path(forResource: "AppIcon", ofType: "png")
            ]
            for path in possiblePaths.compactMap({ $0 }) {
                if let image = NSImage(contentsOfFile: path) {
                    await MainActor.run {
                        NSApplication.shared.applicationIconImage = image
                    }
                    break
                }
            }
        }
    }
}

@main
struct MDPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var documentStore = DocumentStore.shared

    var body: some Scene {
        WindowGroup {
            MainDocumentView(document: $documentStore.document)
                .frame(minWidth: 700, minHeight: 500)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            Task { @MainActor in
                                documentStore.load(from: url)
                            }
                        }
                    }
                    return true
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            TextEditingCommands()

            CommandGroup(replacing: .newItem) {
                Button("新建文档") {
                    documentStore.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("打开文件...") {
                    documentStore.openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("保存") {
                    documentStore.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("另存为...") {
                    documentStore.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
