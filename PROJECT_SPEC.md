# MDPreview — 纯原生 Markdown 极简阅读/编辑器架构规范 (macOS Native & Liquid Glass)

> **定位**：100% 采用 Apple 原生技术栈构建的 macOS 极简 Markdown 文档阅读器与编辑器。
> 摒弃任何 Web 容器（无 WebKit / HTML / JS 开销），基于 `swift-markdown`、`TextKit 2` 与 `SwiftUI` 打造，全面拥抱 **Liquid Glass (macOS 27+ / Visionary HIG)** 设计语言。

---

## 1. 核心设计哲学 (Design Philosophy)

* **100% 纯原生渲染 (Zero WebKit Overhead)**：
  * 完全舍弃 Web 视图，不加载庞大的 Web 渲染引擎进程。
  * 纯原生绘制：冷启动 `< 30ms`，基础内存占用 `< 15MB`，滚动和选区具备 120Hz ProMotion 丝滑帧率。
* **macOS 27+ 前瞻设计规范 (Liquid Glass & Modern HIG)**：
  * **流体材质与液态玻璃 (Liquid Glass)**：统一工具栏、悬浮指示器与控制组采用 `.glassEffect()` 与 `GlassEffectContainer`，具备光影互动反射与物理弹簧动效。
  * **自适应向后兼容**：高版本激活 Liquid Glass 流体交互，同时向下兼容 `.ultraThinMaterial` / `NSVisualEffectView`。
* **Finder 亲和性与文档中心化 (Document-Centric)**：
  * 依托 `DocumentGroup` 和 `FileDocument`，完美继承 macOS 原生多窗口、多标签（Tabs）、代理图标（Proxy Icon）拖拽、版本快照（Versions）及快捷保存机制。

---

## 2. 纯原生技术栈选型 (Pure Native Tech Stack)

| 层次 | 核心技术 | 说明与选型理由 |
| :--- | :--- | :--- |
| **语言与并发** | **Swift 6+** | 启用严格并发安全检查（Strict Concurrency Checking, `Sendable`, Swift Actors） |
| **应用与窗口体系** | **SwiftUI + AppKit** | `DocumentGroup` + `NavigationSplitView`，窗口级别无边界融合 |
| **UI 材质与动效** | **Liquid Glass API** | `GlassEffectContainer` + `.glassEffect()`，结合 SwiftUI 物理弹性动画 |
| **Markdown AST 解析** | **`apple/swift-markdown`** | 苹果官方基于 cmark-gfm 开发的 Swift 抽象语法树（AST）引擎，高效、内存安全 |
| **排版与渲染 (阅读态)** | **SwiftUI Native Tree + CoreText** | 针对 AST 节点生成纯原生 SwiftUI 组件树（支持原生选择、右键菜单、平滑缩放） |
| **编辑核心 (编辑态)** | **TextKit 2 (`NSTextView`)** | 基于 `NSTextLayoutManager` 与 `NSTextContentStorage`，支持行号、语法高亮与丝滑输入 |
| **文件与系统监听** | **`DispatchSourceFileSystemObject`** | 零依赖监听 Finder 中文件的外部变更，实现静默热重载 |
| **系统预览扩展** | **`QuickLookThumbnailing` / `QuickLook`** | 原生 Quick Look 插件，Finder 空格键毫秒级唤起原生渲染 |

---

## 3. UI/UX 与视觉设计规范 (Liquid Glass HIG)

### 3.1 窗口与布局架构
```
+-----------------------------------------------------------------------------------+
|  [●][●][●]  📄 架构设计.md  [ [大纲] [ 📖 阅读 | ✏️ 编辑 ] [ 🔎 查找 ] [ 📤 导出 ] ] | (Liquid Glass Toolbar)
+-----------------------+-----------------------------------------------------------+
| 📑 目录大纲 (TOC)      |                                                           |
| (Glass Sidebar)       |  # 1. 架构总览                                            |
|                       |                                                           |
| > 1. 架构总览          |  这是正文段落，采用 **SF Pro Text**，遵循精准行距倍率。   |
|   > 1.1 性能指标      |                                                           |
|   > 1.2 内存模型      |  > 引用段落使用原生毛玻璃边框与衬线体展示                 |
| > 2. 原生渲染引擎     |                                                           |
| > 3. Liquid Glass     |  ```swift                                                 |
|                       |  let reader = NativeMarkdownReader()                      |
|                       |  ```                                                      |
|                       |                                                           |
|                       |  | 特性       | 传统 WebKit | 纯原生 TextKit 2 |            |
|                       |  | :--------- | :---------- | :--------------- |            |
|                       |  | 内存占用   | ~80MB       | < 15MB           |            |
|                       |  | 启动耗时   | ~180ms      | < 30ms           |            |
|                       |                                                           |
| (可快捷收起 ⌘⌥S)       |  - [x] 纯原生渲染                                         |
|                       |  - [ ] 导出 PDF                                           |
+-----------------------+-----------------------------------------------------------+
| 🪟 浮动状态条 (Glass Capsule): 1,420 字符 · 3 分钟阅读 · UTF-8 (自动淡出)          |
+-----------------------------------------------------------------------------------+
```

### 3.2 Liquid Glass 关键交互规范
1. **统一胶囊工具栏 (Unified Glass Toolbar)**：
   - 工具栏控件使用 `GlassEffectContainer` 聚合，支持鼠标悬停时自发光微光泽（Specular Highlight）。
   - 模式切换按钮采用 `.buttonStyle(.glassProminent)` 与 `.buttonStyle(.glass)` 区分阅读与编辑状态。
2. **浮动状态气泡 (Floating Glass Capsule)**：
   - 底部字数与阅读时长显示于微型 Liquid Glass 悬浮气泡中，鼠标静止时优雅渐隐（Fade to 40% alpha），不遮挡正文。
3. **原生排印体系 (Apple Typography Hierarchy)**：
   - **标题**：`Font.system(.title, design: .default).weight(.semibold)`
   - **正文**：`Font.system(.body, design: .default)`（字距与行高依据 macOS HIG 黄金比例微调）
   - **代码**：`Font.system(.body, design: .monospaced)`，搭配极简半透明圆角代码背景
   - **数学公式与表格**：原生符号与 SwiftUI `Grid` 紧凑网格。

---

## 4. 纯原生 Markdown 渲染器架构设计 (Native Engine Pipeline)

### 4.1 渲染管线 (Pipeline Architecture)
```
       [ .md 原始文件 / String ]
                   │
                   ▼
       ┌───────────────────────┐
       │  apple/swift-markdown │  (AST 解析器)
       └───────────┬───────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │   MarkupWalker 遍历器  │  (将 AST 转换为类型安全的 Native Nodes)
       └───────────┬───────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
         ▼                   ▼
┌──────────────────┐ ┌──────────────────┐
│   TOC Extractor  │ │ Native View Gen  │
│ (提取 H1-H6 大纲) │ │ (构建 SwiftUI 树) │
└──────────────────┘ └─────────┬────────┘
                               │
                               ▼
                     ┌───────────────────┐
                     │ MarkdownBodyView  │ (原生 LazyVStack / CoreText)
                     └───────────────────┘
```

### 4.2 节点映射表 (Native Component Mapping)

| Markdown 语法 | 原生渲染策略 |
| :--- | :--- |
| **Heading 1~6** | `HeadingView` (带锚点 ID 供 TOC 滚动导航，字体尺寸分级) |
| **Paragraph / Text** | `Text(AttributedString)` (行内加粗/斜体/超链接/行内代码由 AttributedString 原生处理) |
| **Code Block** | `CodeBlockView` (带语法高亮分词、一键复制按钮、横向滚动、SF Mono 字体) |
| **Table** | `Grid` + `GridRow` (原生自适应列宽、斑马条纹背景、支持选择) |
| **Blockquote** | `BlockquoteView` (左侧原生 Accent 强调线 + 浅色底衬) |
| **List (Ordered/Unordered/Task)** | `TaskItemView` / `ListItemView` (原生 Checkbox 支持交互反写回文档) |
| **Thematic Break (HR)** | `Divider()` (带轻微渐变边距) |

---

## 5. 项目代码组织结构 (Pure Native Architecture)

```text
MDPreview/
├── Package.swift                    // 声明 SPM 依赖 (apple/swift-markdown 等)
├── Sources/
│   ├── MDPreviewApp/
│   │   ├── MDPreviewApp.swift       // App 入口 (DocumentGroup 声明)
│   │   └── Info.plist               // macOS 文件关联 (Document Types / UTI)
│   │
│   ├── Models/
│   │   ├── MarkdownDocument.swift   // FileDocument 协议实现（支持数据序列化与自动保存）
│   │   ├── DocumentContent.swift    // 纯文本内容与 AST 缓存包装
│   │   ├── TOCItem.swift            // 目录树节点模型 (Identifiable, Hashable)
│   │   └── AppPreferences.swift     // 用户偏好（字体排印、行距、主题模式）
│   │
│   ├── Engine/
│   │   ├── MarkdownParser.swift     // 基于 swift-markdown 的 AST 解析服务
│   │   ├── ASTToViewBuilder.swift   // 将 Document 节点转为原生 View 结构
│   │   ├── SyntaxHighlighter.swift  // 纯 Swift 极速代码语法着色引擎
│   │   └── FileMonitor.swift        // DispatchSourceFileSystemObject 外部变更监听
│   │
│   ├── UI/
│   │   ├── Glass/
│   │   │   ├── GlassCompatibility.swift // Liquid Glass (#available) 与 Material 统一抽象
│   │   │   └── GlassToolbar.swift       // 统一流体工具栏
│   │   │
│   │   ├── Reading/
│   │   │   ├── NativeReaderView.swift   // 纯原生阅读器容器 (ScrollViewReader 锚点跳转)
│   │   │   ├── BlockElements.swift      // 标题、代码块、引用、表格等原生组件
│   │   │   └── TOCSidebarView.swift     // 原生大纲侧边栏 (List + OutlineGroup)
│   │   │
│   │   ├── Editor/
│   │   │   ├── NativeEditorView.swift   // TextKit 2 (NSTextView) 原生编辑器封装
│   │   │   └── LineNumberRulerView.swift// 极简原生行号尺
│   │   │
│   │   ├── Components/
│   │   │   ├── FloatingStatusCapsule.swift // 底部悬浮信息胶囊
│   │   │   └── SearchOverlayView.swift     // 原生文本快速查找栏
│   │   │
│   │   └── Windows/
│   │       └── DocumentContentView.swift   // 主视图：SplitView + 阅读/编辑路由
│   │
│   └── System/
│       ├── PDFExporter.swift        // 原生 NSHostingView 绘制生成矢量 PDF
│       └── PrintHandler.swift       // macOS 标准打印管道集成
│
└── Tests/
    ├── MDPreviewTests/
    └── ParserPerformanceTests/      // AST 解析与布局基准性能测试 (<10ms 目标)
```

---

## 6. Liquid Glass 代码集成示例 (Code Standard)

```swift
import SwiftUI

/// 统一适配 macOS 27+ Liquid Glass 及旧版本 Material 材质的视图修饰器
struct AdaptiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 27, iOS 26, *) {
            if isInteractive {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            // 向后兼容 macOS 14 / 15 原生材质
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
    }
}

extension View {
    func adaptiveGlass(cornerRadius: CGFloat = 12, isInteractive: Bool = false) -> some View {
        self.modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}
```

---

## 7. 演进路线 (Roadmap)

1. **里程碑 1：原生解析管线与 Document 容器**
   - 配置 SPM 项目与 `apple/swift-markdown` 依赖。
   - 实现 `FileDocument` 数据模型与双向响应。
2. **里程碑 2：纯原生 Block 级阅读器与大纲侧边栏**
   - 渲染 Heading（带 ID 锚点）、Paragraph、List、Quote。
   - 原生 CodeBlock 语法着色与 SwiftUI Grid 表格。
   - `ScrollViewReader` 实现大纲点击精准平滑滚动。
3. **里程碑 3：TextKit 2 极速编辑器与 Liquid Glass 界面打磨**
   - `NSTextView` 封装与行号支持。
   - `⌘E` 丝滑切换动画与 Liquid Glass 胶囊工具栏。
   - 原生 PDF 导出与外部修改热重载。
