# MDPreview (v1.1.0)

<p align="center">
  <img src="Resources/AppIcon.png" alt="MDPreview Logo" width="128" height="128" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
</p>

<p align="center">
  <strong>100% 纯原生 macOS 极简 Markdown 阅读与编辑器</strong><br>
  <em>Zero WebKit Overhead · Apple Native Engine · Liquid Glass Modern HIG · Document-Based Multi-Window</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v1.1.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-lightgrey.svg" alt="macOS">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2F%20Intel-success.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</p>

---

## 📖 项目简介 (Introduction)

**MDPreview** 是一款完全采用 Apple 原生技术栈构建的 macOS 极简 Markdown 文档阅读器与轻量编辑器。

不同于市面上常见的基于 Electron 或 WebKit (HTML/JS) 渲染的 Markdown 工具，MDPreview 彻底摒弃了庞大的 Web 容器，基于 **`apple/swift-markdown`** 语法树、**`TextKit 2`** 与 **`SwiftUI NavigationSplitView / DocumentGroup`** 原生文档型架构打造，深度拥抱 **Liquid Glass** 现代流体视觉设计。

* **极致轻量**：冷启动耗时 `< 30ms`，空载内存占用 `< 15MB`。
* **丝滑渲染**：纯原生组件树与 CoreText 排印，120Hz ProMotion 丝滑滚动体验。
* **原生体验**：深度整合 macOS 窗口系统、多标签页（Multi-Tab）、文件关联（Open With）、拖拽交互与系统快捷键。

---

## ✨ 核心特性 (Features)

### 1. 🚀 纯原生渲染引擎 (Zero WebKit Overhead)
- 基于 Apple 官方 **`swift-markdown` (cmark-gfm AST)** 引擎进行底层解析。
- 无需 Chromium/WebKit 渲染进程，告别卡顿与发热，极大降低系统资源开销。

### 2. 🗂️ 原生文档架构与多标签页 (Document-Based Multi-Window & Tabs)
- 采用 SwiftUI 原生 `DocumentGroup` 架构，与 macOS 系统深度契合。
- 支持在 Finder 中右键任意 `.md` 文件选择「打开方式 -> MDPreview」精准独立加载。
- 每次打开新文件或按 `⌘O` / `⌘N` 时，自动在独立新窗口或新 Tab 标签页中呈现，互不干扰。
- 完整支持 macOS 原生标签页合并（Merge All Windows）与窗口拆分。

### 3. 🎨 Liquid Glass 现代美学与统一原生工具栏
- 遵循 macOS 前瞻设计语言，采用通透的流体玻璃材质（`.glassEffect` 与毛玻璃自适应）。
- **Preview（预览.app）风格联动布局**：侧边栏展开时，文档标题自然对齐于主内容区上方；侧边栏收起时，标题平滑滑动跟随左上角按钮。
- **居中分段控制器**：顶部工具栏正中央提供紧凑的「阅读 / 编辑 / 分屏」三模快速切换。

### 4. 📑 智能目录大纲 (TOC Sidebar)
- 自动提取文档中 `H1` ~ `H6` 标题层级，生成清晰的目录树。
- 接入系统原生 `NavigationSplitView`，支持侧边栏快捷折叠/展开（快捷键 `⌘⌥S`），点击平滑滚动定位正文。

### 5. ⚡️ 阅读 / 编辑 / 分屏三模秒切
- **📖 纯净阅读模式 (Reader View)**：针对排版深度优化的原生富文本展示，完美支持标题、高亮（`==高亮==`）、行内样式、引用块、有序/无序列表、任务清单、分割线等。
- **✏️ 原生编辑模式 (Editor View)**：基于现代 **TextKit 2 (`NSTextView`)** 打造，支持快速编辑与双向实时同步。
- **🪟 左右分屏模式 (Split View)**：左侧即时编辑，右侧实时流式渲染预览。

### 6. 💻 原生代码语法高亮 (Syntax Highlighting)
- 内置针对 Swift、Python、JavaScript/TypeScript、JSON、Shell、HTML/CSS 等主流语言的纯原生语法高亮引擎。
- 搭配圆角浅底代码容器，阅读更舒适。

### 7. 🔍 悬浮状态胶囊 (Floating Glass Capsule)
- 右下角常驻显示当前文档字数（中文按字、拉丁按词计）。
- 鼠标悬停时展开显示行数；静止时自动淡出，不打扰阅读焦点。

### 8. 📑 目录大纲滚动联动
- 阅读时正文滚动，侧边栏自动高亮当前所在章节。
- 引用块 / 列表内部的 `#` 标题不会污染大纲层级。

### 9. 📂 Finder 深度整合与拖拽支持
- 支持文件拖拽：直接将本地 `.md` 文件拖入窗口即可打开。
- 支持文件关联：原生支持 `.md`、`.markdown`、`.mdown`、`.mkdn` 等文档格式。

---

## 🚧 规划中 (Roadmap)

以下功能尚未实现，欢迎 PR：

- 编辑器行号标尺与 Markdown 语法高亮
- 文档内查找 (`⌘F`) 与替换
- 导出矢量 PDF / 打印 (`⌘P`)
- 外部修改静默热重载（Finder 中改动自动刷新）
- 偏好设置（字体、行距、主题、版心宽度）
- Finder Quick Look 快速预览插件

---

## ⌨️ 常用快捷键 (Keyboard Shortcuts)

| 快捷键 | 功能说明 |
| :--- | :--- |
| `⌘ R` | 切换至阅读模式 (Reader View) |
| `⌘ E` | 切换至编辑模式 (Editor View) |
| `⇧ ⌘ E` | 切换至分屏模式 (Split View) |
| `⌘ ⌥ S` | 展开 / 收起目录大纲侧边栏 |
| `⌘ N` | 新建文档窗口 / Tab |
| `⌘ O` | 打开本地 Markdown 文件 |
| `⌘ S` | 保存当前文档 |
| `⌘ ⇧ S` | 另存为新文件 |
| `⌘ W` | 关闭当前窗口 / 标签页 |
| `⌘ Q` | 退出应用程序 |

---

## 🛠️ 系统要求 (System Requirements)

- **运行**：macOS 14.0 (Sonoma) 或更高版本（Liquid Glass 材质需 macOS 26+，低版本自动回退毛玻璃）
- **硬件平台**：Apple Silicon 及 Intel
- **开发**：完整版 Xcode 16+（Swift 6）与 [`xcodegen`](https://github.com/yonaskolb/XcodeGen)

---

## 📦 安装与编译构建 (Installation & Build)

### 方式一：使用 DMG 安装包 (Recommended)
1. 从 [Releases](https://github.com/TonyT1226/md-reader/releases) 页面下载 **`MDPreview.dmg`**。
2. 双击打开，将 **`MDPreview.app`** 拖入 **`Applications`** 文件夹。
3. 双击运行，或在任意 `.md` 文件右键「打开方式 → MDPreview」。

### 方式二：从源码构建

```bash
git clone https://github.com/TonyT1226/md-reader.git
cd md-reader

# 只跑解析核心 + 单测（需完整 Xcode 工具链）
swift test

# 生成并打开 App 工程
brew install xcodegen
xcodegen generate
open MDPreview.xcodeproj      # 在 Xcode 里 Run / 预览 / 归档

# 或命令行打包 DMG
./package_app.sh
```

> 详见 [CONTRIBUTING.md](CONTRIBUTING.md)。若遇到 “no such module 'Testing'”、
> SwiftUI 预览无法加载、运行后不开窗，通常是 `xcode-select` 指向了 Command Line Tools，
> 执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` 即可。

---

## 📄 开源许可 (License)

本项目采用 [MIT License](LICENSE) 开源协议。
