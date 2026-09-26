import AppKit
import UniformTypeIdentifiers

/// 粘贴 / 拖入编辑器的图片：存到文档旁的 `assets/`，生成 Markdown 引用。
public enum ImageAssets {

    public static let folderName = "assets"

    /// 一张待保存的图片
    public struct Source: Equatable, Sendable {
        public let data: Data
        /// 扩展名（不带点），如 `png`
        public let fileExtension: String

        public init(data: Data, fileExtension: String) {
            self.data = data
            self.fileExtension = fileExtension
        }
    }

    // MARK: - 从粘贴板取图

    /// 粘贴板里要按图片处理的内容；返回空数组表示按普通粘贴处理。
    ///
    /// - 有图片文件（Finder 里复制 / 拖入的图片）→ 读这些文件
    /// - 只有图片数据、没有文字（截图、从预览复制）→ 读图片数据
    /// - 同时有文字（Excel、网页、Word 常会顺带一张图）→ 不管，按文字粘贴
    public static func sources(from pasteboard: NSPasteboard) -> [Source] {
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL]) ?? []
        if !urls.isEmpty {
            let images = urls.filter { url in
                (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) == true
            }
            // 混着非图片文件时整体交给默认行为，避免只插入一部分
            guard images.count == urls.count else { return [] }
            return images.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
                return Source(data: data, fileExtension: ext)
            }
        }

        let types = pasteboard.types ?? []
        guard !types.contains(.string) else { return [] }
        if let png = pasteboard.data(forType: .png) {
            return [Source(data: png, fileExtension: "png")]
        }
        if let tiff = pasteboard.data(forType: .tiff), let png = pngData(fromTIFF: tiff) {
            return [Source(data: png, fileExtension: "png")]
        }
        return []
    }

    /// 粘贴板上是否可能有图片（用来决定是否声明可读图片类型）
    public static let readableTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

    static func pngData(fromTIFF tiff: Data) -> Data? {
        NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    // MARK: - 文件名与保存

    /// 「文档名-时间[-序号].扩展名」；空格、括号等会破坏 Markdown 链接的字符换成 `-`
    public static func fileName(documentStem: String, fileExtension: String, date: Date, index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let unsafe = CharacterSet(charactersIn: " \t()[]<>#?%\"'\\/:")
        let stem = documentStem.components(separatedBy: unsafe).filter { !$0.isEmpty }.joined(separator: "-")
        let base = (stem.isEmpty ? "image" : stem) + "-" + formatter.string(from: date)
        return (index == 0 ? base : "\(base)-\(index)") + "." + fileExtension
    }

    /// 把图片写进 `<文档目录>/assets/`，返回相对文档目录的路径（如 `assets/笔记-20260924-101500.png`）。
    /// 已有同名文件时序号往后顺延，绝不覆盖。
    public static func save(_ sources: [Source], documentURL: URL, date: Date = Date()) throws -> [String] {
        let fm = FileManager.default
        let folder = documentURL.deletingLastPathComponent().appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = documentURL.deletingPathExtension().lastPathComponent

        var paths: [String] = []
        var index = 0
        for source in sources {
            var name: String
            repeat {
                name = fileName(documentStem: stem, fileExtension: source.fileExtension, date: date, index: index)
                index += 1
            } while fm.fileExists(atPath: folder.appendingPathComponent(name).path)
            try source.data.write(to: folder.appendingPathComponent(name), options: .withoutOverwriting)
            paths.append(folderName + "/" + name)
        }
        return paths
    }

    /// 每张图一行 `![](路径)`
    public static func markdown(for paths: [String]) -> String {
        paths.map { "![](\($0))" }.joined(separator: "\n")
    }
}
