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
        setupAppIconAsync()
    }

    private func setupAppIconAsync() {
        Task.detached(priority: .background) {
            let possiblePaths = [
                "Resources/AppIcon.icns",
                "../Resources/AppIcon.icns",
                Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
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
        }
    }
}
