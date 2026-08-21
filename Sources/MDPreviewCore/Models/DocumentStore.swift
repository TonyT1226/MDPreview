import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 全局与窗口级文档状态管理器（支持 Xcode 调试、Terminal 启动与 .app 打包全环境）
@MainActor
public final class DocumentStore: ObservableObject {
    public static let shared = DocumentStore()

    @Published public var document: MarkdownDocument
    @Published public var fileURL: URL? = nil
    @Published public var documentTitle: String = "欢迎使用 MDPreview.md"

    public init(text: String = defaultWelcomeText) {
        self.document = MarkdownDocument(text: text)
    }

    public func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let string = String(data: data, encoding: .utf8) {
                self.document = MarkdownDocument(text: string)
                self.fileURL = url
                self.documentTitle = url.lastPathComponent
            }
        } catch {
            print("无法打开文件: \(error)")
        }
    }

    public func save() {
        if let url = fileURL {
            try? document.text.write(to: url, atomically: true, encoding: .utf8)
        } else {
            saveAs()
        }
    }

    public func saveAs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText, UTType(importedAs: "net.daringfireball.markdown")]
        savePanel.nameFieldStringValue = fileURL?.lastPathComponent ?? "未命名.md"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            self.fileURL = url
            self.documentTitle = url.lastPathComponent
            try? document.text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public func openFilePanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.plainText, UTType(importedAs: "net.daringfireball.markdown"), .text]
        if openPanel.runModal() == .OK, let url = openPanel.url {
            load(from: url)
        }
    }

    public func newDocument() {
        self.document = MarkdownDocument(text: "")
        self.fileURL = nil
        self.documentTitle = "未命名.md"
    }
}

public let defaultWelcomeText = """
# 欢迎使用 MDPreview

极简、轻量、100% 纯原生渲染的 macOS Markdown 文档查看与快速编辑器。

---

## ⚡ 特性亮点

* **纯原生 AST 渲染**：基于 `apple/swift-markdown`，零 Web 容器开销。
* **Liquid Glass 交互**：专为 macOS 27+ 设计的流体毛玻璃工具栏与状态胶囊。
* **双模秒切**：按下 `⌘ + E` 即可在阅读与编辑模式之间瞬间切换。
* **大纲导航**：左侧原生 TOC 目录树，点击平滑滚动。
* **重点高亮**：原生支持 ==高亮文本== 标记。

### 常用快捷键

| 快捷键 | 功能 |
| :--- | :--- |
| `⌘ + E` | 切换阅读 / 编辑视图 |
| `⌘ + ⌥ + 1` | 纯阅读模式 |
| `⌘ + ⌥ + 2` | 纯编辑模式 |
| `⌘ + ⌥ + 3` | 左右分屏模式 |
| `⌘ + ⌥ + S` | 显示 / 隐藏大纲侧边栏 |
| `⌘ + P` | 打印 / 导出 PDF |
| `⌘ + O` | 打开本地 Markdown 文件 |
| `⌘ + S` | 保存文档 |

### 代码高亮演示

```swift
import SwiftUI
import Markdown

struct NativeReader: View {
    var body: some View {
        Text("Hello Native macOS!")
            .font(.title)
    }
}
```

- [x] 纯原生渲染管线
- [x] macOS Liquid Glass 设计规范
- [x] 毫秒级冷启动与超低内存
"""
