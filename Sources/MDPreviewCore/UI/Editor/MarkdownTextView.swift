import AppKit

/// 编辑器文本视图：在 NSTextView 的基础上接管图片的粘贴与拖入。
///
/// 由 `MarkdownTextView.scrollableTextView()` 创建，仍是系统搭好的 TextKit 2 栈。
final class MarkdownTextView: NSTextView {

    /// 当前文档在磁盘上的位置；未保存的新文档为 nil
    var documentURL: () -> URL? = { nil }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        ImageAssets.readableTypes + super.readablePasteboardTypes
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        let sources = ImageAssets.sources(from: pboard)
        guard !sources.isEmpty else { return super.readSelection(from: pboard, type: type) }
        // 粘贴 / 拖放时的插入点，在弹窗前就记下
        insertImages(sources, at: selectedRange())
        return true
    }

    // MARK: - 插入流程

    private func insertImages(_ sources: [ImageAssets.Source], at range: NSRange) {
        guard let docURL = documentURL() else {
            showAlert(title: L.saveBeforeImageTitle, message: L.saveBeforeImageMessage)
            return
        }

        let proceed = { [weak self] in
            guard let self else { return }
            do {
                let paths = try ImageAssets.save(sources, documentURL: docURL)
                let snippet = ImageAssets.markdown(for: paths)
                let length = (self.string as NSString).length
                let safe = NSRange(location: min(range.location, length),
                                   length: min(range.length, max(0, length - range.location)))
                self.window?.makeFirstResponder(self)
                self.apply(TextEdit(range: safe, replacement: snippet,
                                    selection: NSRange(location: safe.location + (snippet as NSString).length, length: 0)))
            } catch {
                self.showAlert(title: L.imageSaveFailedTitle, message: error.localizedDescription)
            }
        }

        if UserDefaults.standard.bool(forKey: PrefKey.imageNoticeSuppressed) {
            proceed()
            return
        }

        let alert = Self.imageNoticeAlert(documentURL: docURL)

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            // 只有选了「插入」才记住「不再显示」，免得一次取消让以后都静默插入
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: PrefKey.imageNoticeSuppressed)
            }
            proceed()
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    /// 插入图片前的说明弹窗（带「不再显示」）
    static func imageNoticeAlert(documentURL: URL) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L.imageNoticeTitle
        let folder = documentURL.deletingLastPathComponent().lastPathComponent + "/" + ImageAssets.folderName
        alert.informativeText = L.imageNoticeMessage(folder: folder)
        alert.addButton(withTitle: L.imageNoticeInsert)
        alert.addButton(withTitle: L.cancel)
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L.dontShowAgain
        return alert
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L.ok)
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
