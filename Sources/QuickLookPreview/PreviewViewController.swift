import AppKit
import QuickLookUI
import MDPreviewCore

/// Finder 空格预览：用 App 同一套阅读区排版显示 Markdown
final class PreviewViewController: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 820, height: 900)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let text = try QuickLookSupport.readText(at: url)
        await MainActor.run {
            let content = QuickLookSupport.previewView(markdown: text, baseURL: url.deletingLastPathComponent())
            content.frame = view.bounds
            content.autoresizingMask = [.width, .height]
            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(content)
        }
    }
}
