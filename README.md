# MDPreview (v1.0.0)

<p align="center">
  <img src="Resources/AppIcon.png" alt="MDPreview Logo" width="128" height="128" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
</p>

<p align="center">
  <strong>100% 纯原生 macOS 极简 Markdown 阅读与编辑器</strong><br>
  <em>Zero WebKit Overhead · Apple Native Engine · Liquid Glass Modern HIG · Document-Based Multi-Window</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Swift-6.0%20%2F%205.10-orange.svg" alt="Swift">
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
- 动态统计当前文档的字数与行数。
- 悬浮于右下角，支持鼠标悬停增强、静止自动淡出，避免打扰阅读焦点。

### 8. 📂 Finder 深度整合与拖拽支持
- 支持文件拖拽：直接将本地 `.md` 文件拖入窗口即可开启新标签页。
- 支持文件关联：原生支持 `.md`、`.markdown`、`.mdown`、`.mkdn`、`.txt` 等文档格式。

---

## ⌨️ 常用快捷键 (Keyboard Shortcuts)

| 快捷键 | 功能说明 |
| :--- | :--- |
| `⌘ R` | 切换至阅读模式 (Reader View) |
| `⌘ E` | 切换至编辑模式 (Editor View) |
| `⌘ D` | 切换至分屏模式 (Split View) |
| `⌘ N` | 新建文档窗口 / Tab |
| `⌘ O` | 打开本地 Markdown 文件 |
| `⌘ S` | 保存当前文档 |
| `⌘ ⇧ S` | 另存为新文件 |
| `⌘ ⌥ S` | 展开 / 收起目录大纲侧边栏 |
| `⌘ P` | 打印 / 导出 PDF |
| `⌘ W` | 关闭当前窗口 / 标签页 |
| `⌘ Q` | 退出应用程序 |

---

## 🛠️ 系统要求 (System Requirements)

- **操作系统**：macOS 14.0 (Sonoma) 或更高版本（推荐 macOS 15+）
- **硬件平台**：Apple Silicon (M1/M2/M3/M4 系列) 及 Intel 架构芯片
- **编译依赖**：Xcode 15.0+ 或 Swift 5.10+ 工具链

---

## 📦 安装与编译构建 (Installation & Build)

### 方式一：使用 DMG 安装包 (Recommended)
1. 从 Release 页面或项目根目录获取 **`MDPreview.dmg`**。
2. 双击打开 `MDPreview.dmg`，将 **`MDPreview.app`** 拖入 **`Applications`** 文件夹。
3. 双击即可直接运行，或在任意 `.md` 文件右键选择 MDPreview 打开。

### 方式二：从源码编译运行

```bash
# 1. 克隆项目仓库
git clone https://github.com/TonyT1226/md-reader.git
cd md-reader

# 2. 编译并运行
swift run

# 3. 命令行打开指定文件
swift run MDPreview SampleDocument.md

# 4. 构建 Release 优化二进制
swift build -c release
```

---

## 📄 开源许可 (License)

本项目采用 [MIT License](LICENSE) 开源协议。
