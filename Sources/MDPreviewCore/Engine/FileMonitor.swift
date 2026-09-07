import Foundation

/// 监听单个文件的外部变更（`DispatchSourceFileSystemObject`）。
///
/// - 内部状态只在私有串行队列上改动；`onChange` 回调派发到主线程
/// - 事件合并 150ms，避免一次保存触发多次回调
/// - 处理原子保存：编辑器常「写临时文件 → rename 覆盖」，旧 fd 会指向被 unlink 的 inode；
///   检测到 inode 变化就按原路径重新挂载
public final class FileMonitor: @unchecked Sendable {

    public enum Event: Sendable {
        case modified
        case deleted
    }

    private let url: URL
    private let onChange: @MainActor (Event) -> Void
    private let queue = DispatchQueue(label: "com.mdpreview.filemonitor", qos: .utility)

    // 下面这些只在 `queue` 上访问
    private var source: (any DispatchSourceFileSystemObject)?
    private var descriptor: Int32 = -1
    private var generation = 0

    public init(url: URL, onChange: @escaping @MainActor (Event) -> Void) {
        self.url = url
        self.onChange = onChange
        queue.async { [weak self] in self?.startSource() }
    }

    deinit {
        source?.cancel()
    }

    public func stop() {
        queue.sync { teardownSource() }
    }

    // MARK: - DispatchSource 生命周期（均在 queue 上）

    private func startSource() {
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.scheduleEvaluation()
        }
        let fd = descriptor
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    private func teardownSource() {
        generation += 1        // 作废在途的 debounce
        source?.cancel()       // cancelHandler 负责 close(fd)
        source = nil
        descriptor = -1
    }

    // MARK: - 评估（queue 上）

    private func scheduleEvaluation() {
        generation += 1
        let g = generation
        queue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.generation == g else { return }
            self.evaluate()
        }
    }

    private func evaluate() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            teardownSource()
            deliver(.deleted)
            return
        }
        if isDescriptorStale() {
            teardownSource()
            startSource()   // 重新挂到新 inode（原子保存）
        }
        deliver(.modified)
    }

    /// 当前 fd 是否已不指向该路径现在的文件
    private func isDescriptorStale() -> Bool {
        guard descriptor >= 0 else { return true }
        var fdInfo = Foundation.stat()
        var pathInfo = Foundation.stat()
        guard fstat(descriptor, &fdInfo) == 0,
              stat(url.path, &pathInfo) == 0 else { return true }
        return fdInfo.st_ino != pathInfo.st_ino || fdInfo.st_dev != pathInfo.st_dev
    }

    private func deliver(_ event: Event) {
        let callback = onChange
        DispatchQueue.main.async {
            MainActor.assumeIsolated { callback(event) }
        }
    }

    // MARK: - 读盘（带编码兜底，与 MarkdownDocument 一致）

    /// 经 `NSFileCoordinator` 读取文件文本；失败返回 nil
    public static func readText(at url: URL) -> String? {
        var result: String?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            if let s = String(data: data, encoding: .utf8) { result = s }
            else if let s = String(data: data, encoding: .utf16) { result = s }
            else if let s = String(data: data, encoding: .isoLatin1) { result = s }
        }
        return result
    }
}
