import AppKit

/// 沙盒里访问文档所在文件夹的授权。
///
/// 沙盒里 App 只能读写用户打开的那个文件；同目录的本地图片、链接到的其他 .md、
/// 粘贴图片时写入的 `assets/` 都要用户另外授权。做法是让用户在打开面板里选中文件夹，
/// 存成 security-scoped bookmark，下次启动时恢复。授权一个文件夹也覆盖它的所有子文件夹。
///
/// 不在沙盒里（开发构建、GitHub 上的 DMG）时什么都不用做，`needsAccess` 总是 false。
@MainActor
public final class FolderAccess: ObservableObject {

    public static let shared = FolderAccess(defaults: .standard)

    /// 授权变化（新增或移除）后发出，阅读区据此重新渲染图片
    public static let didChange = Notification.Name("MDPreview.folderAccessDidChange")

    public static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// 已授权的文件夹，按路径排序
    @Published public private(set) var folders: [URL] = []

    private let defaults: UserDefaults
    /// 已调用 `startAccessingSecurityScopedResource` 的文件夹
    private var accessing: [URL] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - 启动时恢复

    /// 解析存下的 bookmark 并开始访问。解析失败的（文件夹被删了等）直接丢掉，过期的重新生成。
    public func restore() {
        var stored = storedBookmarks
        var changed = false
        for (path, data) in stored {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: Self.resolveOptions,
                                     relativeTo: nil, bookmarkDataIsStale: &stale) else {
                stored[path] = nil
                changed = true
                continue
            }
            startAccessing(url)
            if stale || url.path != path, let fresh = Self.bookmark(for: url) {
                stored[path] = nil
                stored[url.path] = fresh
                changed = true
            }
        }
        if changed { storedBookmarks = stored }
        folders = accessing.sorted { $0.path < $1.path }
    }

    // MARK: - 查询

    /// `url` 是否落在某个已授权的文件夹里（含文件夹本身）
    public func isGranted(_ url: URL) -> Bool {
        folders.contains { Self.folder($0, contains: url) }
    }

    /// 在沙盒里、没授权过、且确实读不了这个文件夹时为 true
    public func needsAccess(to directory: URL) -> Bool {
        Self.isSandboxed && !isGranted(directory) && !Self.canList(directory)
    }

    static func canList(_ directory: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) != nil
    }

    /// 按路径分量比较，`/a/b` 不算包含 `/a/bc`
    static func folder(_ folder: URL, contains url: URL) -> Bool {
        let parent = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let child = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return child.count >= parent.count && Array(child.prefix(parent.count)) == parent
    }

    // MARK: - 请求 / 移除

    /// 弹出打开面板让用户选中 `directory`（可以选它的上级）。
    /// 回调参数为授权后 `directory` 是否可以访问。
    public func requestAccess(to directory: URL, from window: NSWindow?, completion: @escaping @MainActor (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        // 打开面板没法预先选中文件夹；停在上一级，让目标文件夹出现在列表里，由用户点选
        panel.directoryURL = directory.deletingLastPathComponent()
        panel.message = L.folderAccessPanelMessage(folder: directory.lastPathComponent)
        panel.prompt = L.folderAccessPanelPrompt

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else {
                completion(false)
                return
            }
            self.grant(url)
            completion(self.isGranted(directory))
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    /// 记下用户在打开面板里选中的文件夹
    func grant(_ url: URL) {
        guard let data = Self.bookmark(for: url) else { return }
        var stored = storedBookmarks
        stored[url.path] = data
        storedBookmarks = stored
        startAccessing(url)
        folders = accessing.sorted { $0.path < $1.path }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    public func revoke(_ url: URL) {
        var stored = storedBookmarks
        stored[url.path] = nil
        storedBookmarks = stored
        if let index = accessing.firstIndex(where: { $0.path == url.path }) {
            accessing[index].stopAccessingSecurityScopedResource()
            accessing.remove(at: index)
        }
        folders = accessing.sorted { $0.path < $1.path }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    // MARK: - 存储

    private var storedBookmarks: [String: Data] {
        get { defaults.dictionary(forKey: PrefKey.folderBookmarks) as? [String: Data] ?? [:] }
        set { defaults.set(newValue, forKey: PrefKey.folderBookmarks) }
    }

    private func startAccessing(_ url: URL) {
        guard !accessing.contains(where: { $0.path == url.path }) else { return }
        // 不在沙盒里时返回 false，但照样记下，方便统一管理
        _ = url.startAccessingSecurityScopedResource()
        accessing.append(url)
    }

    private static var resolveOptions: URL.BookmarkResolutionOptions {
        isSandboxed ? [.withSecurityScope] : []
    }

    private static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: isSandboxed ? [.withSecurityScope] : [],
                              includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
