import AppKit
import QuickLookThumbnailing
import MDPreviewCore

/// Finder 缩略图：把文档开头画成一页白纸
final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let text: String
        do {
            text = try QuickLookSupport.readText(at: request.fileURL)
        } catch {
            handler(nil, error)
            return
        }

        // 纸张比例（约 A4 竖版），放进请求的最大尺寸里
        let maxSize = request.maximumSize
        let ratio: CGFloat = 1 / 1.3
        var size = CGSize(width: maxSize.height * ratio, height: maxSize.height)
        if size.width > maxSize.width {
            size = CGSize(width: maxSize.width, height: maxSize.width / ratio)
        }

        let box = HandlerBox(handler)
        DispatchQueue.main.async {
            let draw = MainActor.assumeIsolated {
                QuickLookSupport.thumbnailDrawing(markdown: text, size: size)
            }
            box.handler(QLThumbnailReply(contextSize: size, currentContextDrawing: draw), nil)
        }
    }
}

private final class HandlerBox: @unchecked Sendable {
    let handler: (QLThumbnailReply?, Error?) -> Void
    init(_ handler: @escaping (QLThumbnailReply?, Error?) -> Void) { self.handler = handler }
}
