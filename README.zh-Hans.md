# MDPreview

<img src="Resources/AppIcon.png" alt="MDPreview" width="96" align="right">

[English](README.md) · 简体中文

macOS 上的 Markdown 阅读 / 轻量编辑器。用 SwiftUI + AppKit + `apple/swift-markdown` 写成，
不带 WebView。

当前版本：v1.3.0 · 运行需 macOS 14+ · MIT 许可

---

## 功能

- **阅读 / 编辑 / 分屏** 三种视图，`⌘R` / `⌘E` / `⇧⌘E` 切换。
- **阅读区**是一个只读文本视图：可以跨段落、跨列表连续选中复制，`⌘F` 查找，三指轻点查词。
- **渲染**：标题、加粗 / 斜体 / 删除线、行内代码、`==高亮==`、链接、引用、
  有序 / 无序 / 嵌套列表、任务清单、表格、分割线、图片（本地和网络）。
- **代码高亮**：Swift、Python、JavaScript / TypeScript、JSON、Shell、Rust、Go。
- **目录大纲**：自动从 H1–H6 生成，可折叠，点击跳转，滚动时高亮当前章节。
- **链接**：`#标题` 锚点在文内跳转；相对路径的 `.md` 链接在 MDPreview 里打开。
- **任务清单**：在阅读视图里勾选复选框，改动写回源文件。
- **编辑器**：基于 TextKit 2，带行号；可在偏好设置里打开 Markdown 源码着色。
- **编辑辅助**：`⌘B` / `⌘I` / `⌘K` / `⇧⌘K` 加粗 / 斜体 / 链接 / 行内代码；回车自动续写列表，
  空项上回车退出；`Tab` / `⇧Tab` 缩进列表。
- **插入图片**：粘贴或拖入图片，自动存到文档旁的 `assets/` 文件夹并插入引用。
- **偏好设置**（`⌘,`）：字体、字号、行距、版心宽度、浅色 / 深色 / 跟随系统。
  `⌘=` / `⌘-` / `⌘0` 调字号。
- **导出 PDF / 打印**（`⌥⌘P` / `⌘P`）。
- **外部修改热重载**：文件被别的程序改了会自动刷新；有未保存的改动时先询问。
- **Finder 预览**：空格键预览和文件缩略图显示排版后的效果。
- **界面语言**：英文和简体中文，跟随系统设置。
- **无障碍**：VoiceOver 标签；「增强对比度」下边框更深；「减少动态效果」下不播动画。
- **文档型 app**：多窗口、多标签、`.md` 文件关联、拖入打开。
- macOS 26+ 使用 Liquid Glass 材质，更低版本回退到毛玻璃。

## 版本规划

**v1.1**
修正中文输入、任务勾选、嵌套列表、`==` 高亮误伤等问题；补了单元测试和 CI。

**v1.2**
导出 PDF / 打印；外部修改热重载；界面文字收敛到一处。

**v1.3（当前）**
1. 阅读区改成只读的 `NSTextView`，可以跨块连续选择，阅读态可用 `⌘F`。
2. 偏好设置：字体、字号、行距、版心宽度、主题、编辑器行号和源码着色。
3. 界面、菜单、提示接入 String Catalog，提供 `en` + `zh-Hans`。
4. Finder 空格预览和缩略图（Quick Look 扩展）。
5. 无障碍：VoiceOver 标签、增强对比度、减少动态效果。
6. 中英文 README。

DMG 仍是 ad-hoc 签名，没有公证（需要 Apple Developer 账号），首次打开要右键 › 打开。

**v1.4（已合并，未发布）— 编辑体验**
格式快捷键（`⌘B` / `⌘I` / `⌘K` / `⇧⌘K`）；列表回车续写、Tab 缩进；粘贴 / 拖入图片自动存到 `assets/`；
源码视图里加粗不再被染成斜体色。

**v1.5（已合并，未发布）— 性能与热重载**
阅读区只重新渲染改动的块。160KB 文档改一个字，阅读区更新从约 0.8 秒降到约 30 毫秒。
外部修改刷新后不再标成「已编辑」；文件被删后又出现时，继续监听。

**以后**
行内图片、数学公式、HTML 块、更严谨的代码高亮、更多语言。

> 详细设计和已知限制见 [PROJECT_SPEC.md](PROJECT_SPEC.md)。

## 快捷键

| 键 | 作用 |
| :-- | :-- |
| `⌘R` / `⌘E` / `⇧⌘E` | 阅读 / 编辑 / 分屏 |
| `⌘⌥S` | 显示 / 隐藏大纲 |
| `⌘F` | 查找（阅读和编辑视图都可用） |
| `⌘B` / `⌘I` / `⌘K` / `⇧⌘K` | 加粗 / 斜体 / 链接 / 行内代码（编辑视图） |
| `⌘=` / `⌘-` / `⌘0` | 放大 / 缩小 / 默认字号 |
| `⌘,` | 偏好设置 |
| `⌘P` / `⌥⌘P` | 打印 / 导出 PDF |
| `⌘N` / `⌘O` / `⌘S` / `⌘⇧S` | 新建 / 打开 / 保存 / 另存为 |
| `⌘W` / `⌘Q` | 关闭窗口 / 退出 |

## 安装

从 [Releases](https://github.com/TonyT1226/MDPreview/releases) 下载 `MDPreview-<版本号>.dmg`（如 `MDPreview-1.3.0.dmg`），
把 `MDPreview.app` 拖进「应用程序」。首次打开需要右键 › 打开（没有公证）。

Finder 预览扩展在 App 放进「应用程序」并打开过一次后生效。
如果空格预览还是纯文本，到「系统设置 › 通用 › 登录项与扩展 › 快速查看」里确认 MDPreview 已勾选。

## 从源码构建

需要完整版 Xcode 16+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
git clone https://github.com/TonyT1226/MDPreview.git
cd MDPreview

swift test                    # 跑核心库的单元测试

brew install xcodegen
xcodegen generate
open MDPreview.xcodeproj       # 在 Xcode 里运行 / 预览 / 归档

./package_app.sh              # 或：命令行打包 DMG
```

如果 `swift test` 报 `no such module 'Testing'`、SwiftUI 预览打不开、运行后不出窗口，
基本都是 `xcode-select` 指向了 Command Line Tools：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

更多细节见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

[MIT](LICENSE)
