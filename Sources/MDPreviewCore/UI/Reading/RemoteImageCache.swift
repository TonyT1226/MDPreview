import AppKit

/// 远程图片的内存缓存。未命中时后台下载，下载完发 `didLoad` 通知，阅读视图收到后重渲染。
@MainActor
public final class RemoteImageCache: ReaderImageProvider {
    public static let shared = RemoteImageCache()
    public static let didLoad = Notification.Name("MDPreview.RemoteImageCache.didLoad")

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: Set<URL> = []
    /// 失败过的地址不再反复请求（本次运行内）
    private var failed: Set<URL> = []

    private init() {
        cache.countLimit = 128
    }

    public func image(for url: URL) -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard !failed.contains(url), !inFlight.contains(url) else { return nil }
        inFlight.insert(url)
        Task.detached(priority: .utility) {
            let data = try? await URLSession.shared.data(from: url).0
            await MainActor.run {
                RemoteImageCache.shared.finish(url: url, data: data)
            }
        }
        return nil
    }

    public func hasFailed(_ url: URL) -> Bool { failed.contains(url) }

    private func finish(url: URL, data: Data?) {
        inFlight.remove(url)
        if let data, let image = NSImage(data: data) {
            cache.setObject(image, forKey: url as NSURL)
            NotificationCenter.default.post(name: Self.didLoad, object: url)
        } else {
            failed.insert(url)
        }
    }
}
