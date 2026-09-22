# MDPreview

<img src="Resources/AppIcon.png" alt="MDPreview" width="96" align="right">

macOS 上的 Markdown 阅读 / 轻量编辑器。用 SwiftUI + `apple/swift-markdown` 写成，
不带 WebView，文档直接渲染成原生视图。

当前版本：v1.2.0 · 运行需 macOS 14+ · MIT 许可

---

## 功能

- **阅读 / 编辑 / 分屏** 三种视图，`⌘R` / `⌘E` / `⇧⌘E` 切换。
- **渲染**：标题、加粗 / 斜体 / 删除线、行内代码、`==高亮==`、链接、引用、
  有序 / 无序 / 嵌套列表、任务清单、表格、分割线、图片（本地和网络）。
- **代码高亮**：Swift、Python、JavaScript / TypeScript、JSON、Shell、Rust、Go；
  带语言标签和一键复制。
- **目录大纲**：自动从 H1–H6 生成，可折叠，点击跳转，滚动时高亮当前章节。
- **任务清单**：在阅读视图里勾选复选框，改动写回源文件。
- **编辑器**：基于 TextKit 2 的 `NSTextView`，中文输入法和撤销不受实时预览干扰。
- **导出 PDF / 打印**（`⌘P` / `⌥⌘P`）：按块边界分页的矢量 PDF。
- **外部修改热重载**：Finder 或其他编辑器改了文件会自动感知 —— 无本地改动就静默刷新，
  有冲突则询问。
- **文档型 app**：多窗口、多标签、`.md` 文件关联、拖入打开、代理图标。
- macOS 26+ 使用 Liquid Glass 材质，更低版本回退到毛玻璃。

## 版本规划

**v1.1**
修正 v1.0 的一批问题：中文输入掉字 / 光标跳动、按键全量重解析、任务勾选不生效、
嵌套列表被压平、`==` 高亮误伤 `a == b`、引用块标题污染大纲。
工程上改用独立的 `MDPreview.xcodeproj`、锁定依赖版本、补了单元测试和 CI。

**v1.2（当前）**
1. 导出 PDF / 打印（`⌘P` / `⌥⌘P`），按块边界分页。
2. 外部修改热重载（Finder / 其他编辑器改动自动感知，冲突时询问）。
3. 面向用户字符串收敛到一处，为 v1.3 国际化铺路。

> 偏好设置、编辑器行号、源码高亮一度在 v1.2 里做过，评估后推迟到 v1.3 —— 它们和阅读区重写共用同一套排版层，放一起做更顺。
> 源码高亮的实现已保留在代码里（默认关），v1.3 会在偏好设置里给个开关。

**v1.3（计划中）— 阅读区重写 + 国际化 + 偏好设置**
1. 阅读区改成只读的 `NSTextView`（TextKit 2），支持跨段落 / 跨列表连续选择，
   带来阅读态 `⌘F` 查找、原生查词。
2. 偏好设置：字号、行距、版心宽度、字体、明暗主题、编辑器源码高亮开关。
3. 全部界面、菜单、错误提示接入 String Catalog，提供 `en` + `zh-Hans`。
4. Quick Look 缩略图 / 预览扩展（跟随系统语言）。
5. 无障碍：VoiceOver 标签、Dynamic Type、对比度。
6. 双语 README 与 Release notes，DMG 签名公证。

**以后**
行内图片渲染、数学公式、HTML 块、更严谨的代码高亮、完整 RTL 与更多语言。

> 详细路线图见 [PROJECT_SPEC.md](PROJECT_SPEC.md)。

## 快捷键

| 键 | 作用 |
| :-- | :-- |
| `⌘R` / `⌘E` / `⇧⌘E` | 阅读 / 编辑 / 分屏 |
| `⌘⌥S` | 显示 / 隐藏大纲 |
| `⌘P` / `⌥⌘P` | 打印 / 导出 PDF |
| `⌘F` | 查找（编辑视图） |
| `⌘N` / `⌘O` / `⌘S` / `⌘⇧S` | 新建 / 打开 / 保存 / 另存为 |
| `⌘W` / `⌘Q` | 关闭窗口 / 退出 |

## 安装

从 [Releases](https://github.com/TonyT1226/MDPreview/releases) 下载 `MDPreview.dmg`，
把 `MDPreview.app` 拖进「应用程序」。

## 从源码构建

需要完整版 Xcode 16+和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
git clone https://github.com/TonyT1226/MDPreview.git
cd MDPreview

swift test                    # 跑解析核心的单元测试

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
