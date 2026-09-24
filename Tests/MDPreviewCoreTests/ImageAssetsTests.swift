import Testing
import AppKit
@testable import MDPreviewCore

@Suite("编辑器：粘贴 / 拖入图片")
@MainActor
struct ImageAssetsTests {

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdp-img-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func pngData() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("文件名：文档名-时间，破坏链接的字符换成 -")
    func fileNames() {
        let name = ImageAssets.fileName(documentStem: "我的 笔记 (草稿)", fileExtension: "png", date: fixedDate, index: 0)
        #expect(name.hasPrefix("我的-笔记-草稿-"))
        #expect(name.hasSuffix(".png"))
        #expect(!name.contains(" ") && !name.contains("(") && !name.contains(")"))
        let second = ImageAssets.fileName(documentStem: "a", fileExtension: "jpg", date: fixedDate, index: 2)
        #expect(second.hasSuffix("-2.jpg"))
        #expect(ImageAssets.fileName(documentStem: "()", fileExtension: "png", date: fixedDate, index: 0).hasPrefix("image-"))
    }

    @Test("保存到 assets/，同名时顺延不覆盖")
    func saveNeverOverwrites() throws {
        let dir = try tempDir()
        let doc = dir.appendingPathComponent("笔记.md")
        let src = ImageAssets.Source(data: pngData(), fileExtension: "png")

        let first = try ImageAssets.save([src], documentURL: doc, date: fixedDate)
        let second = try ImageAssets.save([src, src], documentURL: doc, date: fixedDate)
        #expect(first.count == 1 && second.count == 2)
        #expect(Set(first + second).count == 3)
        for p in first + second {
            #expect(p.hasPrefix("assets/"))
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(p).path))
        }
        #expect(ImageAssets.markdown(for: first) == "![](\(first[0]))")
    }

    @Test("粘贴板：纯图片 → 图片；图片 + 文字 → 按文字粘贴；图片文件 → 读文件；混了非图片文件 → 默认行为")
    func pasteboardRules() throws {
        let pb = NSPasteboard(name: NSPasteboard.Name("mdp-test-\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }

        pb.clearContents()
        pb.setData(pngData(), forType: .png)
        #expect(ImageAssets.sources(from: pb).count == 1)

        pb.clearContents()
        pb.declareTypes([.string, .png], owner: nil)
        pb.setString("表格里的文字", forType: .string)
        pb.setData(pngData(), forType: .png)
        #expect(ImageAssets.sources(from: pb).isEmpty)

        let dir = try tempDir()
        let img = dir.appendingPathComponent("photo.png")
        try pngData().write(to: img)
        let txt = dir.appendingPathComponent("readme.txt")
        try "x".write(to: txt, atomically: true, encoding: .utf8)

        pb.clearContents()
        pb.writeObjects([img as NSURL])
        let fromFile = ImageAssets.sources(from: pb)
        #expect(fromFile.count == 1)
        #expect(fromFile.first?.fileExtension == "png")

        pb.clearContents()
        pb.writeObjects([img as NSURL, txt as NSURL])
        #expect(ImageAssets.sources(from: pb).isEmpty)
    }

    @Test("编辑器里粘贴图片：存文件并在光标处插入引用（说明弹窗已关闭时）")
    func pasteIntoEditor() throws {
        let key = PrefKey.imageNoticeSuppressed
        let old = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(true, forKey: key)
        defer { UserDefaults.standard.set(old, forKey: key) }

        let dir = try tempDir()
        let doc = dir.appendingPathComponent("doc.md")
        let scroll = MarkdownTextView.scrollableTextView()
        let tv = scroll.documentView as! MarkdownTextView
        tv.allowsUndo = true
        tv.string = "前后"
        tv.documentURL = { doc }
        tv.setSelectedRange(NSRange(location: 1, length: 0))

        let pb = NSPasteboard(name: NSPasteboard.Name("mdp-test-\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }
        pb.clearContents()
        pb.setData(pngData(), forType: .png)

        #expect(tv.readSelection(from: pb, type: .png))
        #expect(tv.string.hasPrefix("前![](assets/doc-"))
        #expect(tv.string.hasSuffix(".png)后"))
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("assets").path)
        #expect(files.count == 1)
    }

    @Test("粘贴文字仍走默认行为")
    func pasteTextUnchanged() {
        let scroll = MarkdownTextView.scrollableTextView()
        let tv = scroll.documentView as! MarkdownTextView
        tv.string = ""
        let pb = NSPasteboard(name: NSPasteboard.Name("mdp-test-\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }
        pb.clearContents()
        pb.setString("hello", forType: .string)
        #expect(tv.readSelection(from: pb, type: .string))
        #expect(tv.string == "hello")
    }
}
