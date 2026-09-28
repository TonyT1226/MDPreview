import Testing
import Foundation
@testable import MDPreviewCore

@Suite("沙盒文件夹授权")
@MainActor
struct FolderAccessTests {

    @Test("按路径分量判断包含关系")
    func containment() {
        let folder = URL(fileURLWithPath: "/Users/me/Notes")
        #expect(FolderAccess.folder(folder, contains: URL(fileURLWithPath: "/Users/me/Notes")))
        #expect(FolderAccess.folder(folder, contains: URL(fileURLWithPath: "/Users/me/Notes/a/b.md")))
        #expect(FolderAccess.folder(folder, contains: URL(fileURLWithPath: "/Users/me/Notes/sub/../img.png")))
        #expect(!FolderAccess.folder(folder, contains: URL(fileURLWithPath: "/Users/me/NotesOld/a.md")))
        #expect(!FolderAccess.folder(folder, contains: URL(fileURLWithPath: "/Users/me")))
    }

    @Test("授权后存下、重启后恢复、移除后清掉")
    func grantRestoreRevoke() throws {
        let suite = "mdp-folder-access-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdp-access-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = FolderAccess(defaults: defaults)
        first.grant(dir)
        #expect(first.isGranted(dir.appendingPathComponent("doc.md")))

        // 模拟重启
        let second = FolderAccess(defaults: defaults)
        #expect(second.folders.isEmpty)
        second.restore()
        #expect(second.isGranted(dir.appendingPathComponent("assets/a.png")))

        second.revoke(try #require(second.folders.first))
        #expect(second.folders.isEmpty)
        let third = FolderAccess(defaults: defaults)
        third.restore()
        #expect(third.folders.isEmpty)
    }

    @Test("文件夹被删后恢复时丢掉它")
    func dropsMissingFolder() throws {
        let suite = "mdp-folder-access-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdp-access-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FolderAccess(defaults: defaults).grant(dir)
        try FileManager.default.removeItem(at: dir)

        let access = FolderAccess(defaults: defaults)
        access.restore()
        #expect(access.folders.isEmpty)
        #expect((defaults.dictionary(forKey: PrefKey.folderBookmarks) ?? [:]).isEmpty)
    }

    @Test("不在沙盒里时从不需要授权")
    func notSandboxed() {
        #expect(!FolderAccess.isSandboxed)
        #expect(!FolderAccess.shared.needsAccess(to: URL(fileURLWithPath: "/nonexistent/folder")))
    }

    @Test("识别本地图片")
    func localImages() {
        func doc(_ md: String) -> Bool {
            MarkdownASTParser.parse(markdown: md).blocks.contains(where: \.containsLocalImage)
        }
        #expect(doc("![](img/a.png)"))
        #expect(doc("![](/Users/me/a.png)"))
        #expect(doc("![](file:///Users/me/a.png)"))
        #expect(doc("> - ![x](a.png)"))
        #expect(!doc("![](https://example.com/a.png)"))
        #expect(!doc("just text"))
    }
}
