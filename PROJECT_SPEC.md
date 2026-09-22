# MDPreview 架构规范 (PROJECT_SPEC)

> **定位**：一款 100% 原生的 macOS Markdown 阅读 / 轻量编辑器。
> 不嵌 WebView、不跑 JS 引擎，`.md` 文本经 [`apple/swift-markdown`](https://github.com/apple/swift-markdown)
> 解析成 AST 后直接生成 SwiftUI 原生视图；编辑器用 TextKit 2 (`NSTextView`)。
>
> 当前版本 **v1.2.0** · 运行需 **macOS 14+** · 构建需 **Xcode 16+** · MIT

本文件描述**当前实际实现**与**下两个版本的路线图**。已知未落地的能力集中在
[§8 已知限制](#8-已知限制known-gaps) 和 [§9 路线图](#9-路线图roadmap)，不要把路线图当成现状。

---

## 1. 设计原则

| 原则 | 含义 | 现状 |
| :-- | :-- | :-- |
| **零 WebKit** | 不加载 Web 渲染进程；冷启动快、内存低、滚动跟手 | ✅ 全链路原生 |
| **文档中心** | 依托 `DocumentGroup` + `FileDocument`，白拿多窗口 / 多标签 / 代理图标 / 版本快照 / 自动保存 | ✅ |
| **Finder 亲和** | `.md` 文件关联、拖入打开、空格键预览 | ✅ 关联 + 拖入；⚠️ Quick Look 扩展未做 |
| **渐进材质** | macOS 26+ 用 Liquid Glass (`.glassEffect`)，14/15 回退 `.ultraThinMaterial` | ✅ 有统一抽象，覆盖面还小 |
| **解析与 UI 解耦** | 解析核心是独立 SPM 库，可单测、可给扩展复用 | ✅ `MDPreviewCore` |

**非目标**（当前阶段明确不做）：所见即所得编辑、协同、插件系统、iOS / iPad 版、云同步。

---

## 2. 技术栈

| 层 | 选型 | 说明 |
| :-- | :-- | :-- |
| 语言 | **Swift 6**（`SWIFT_VERSION = 6.0`，严格并发） | 模型层普遍 `Sendable` |
| App / 窗口 | **SwiftUI `DocumentGroup` + `NavigationSplitView`** | 菜单命令经 `FocusedValue` 桥接到当前窗口 |
| 阅读态渲染 | **SwiftUI 视图树**（`LazyVStack` + `Text(AttributedString)` + `Grid`） | 每个 AST 块 → 一个原生子视图 |
| 编辑态 | **TextKit 2**：`NSTextView.scrollableTextView()`（`NSTextLayoutManager`） | 纯文本、等宽、关闭智能标点 / 拼写 |
| Markdown 解析 | **`apple/swift-markdown`**（cmark-gfm） | 用 `revision` 精确锁定 commit，不发 semver |
| 代码高亮 | 自研 `NativeSyntaxHighlighter`（逐行 + 正则分词） | 7 种语言 + 通用兜底 |
| 材质 / 动效 | `glassEffect` (macOS 26) / `ultraThinMaterial` 回退 + SwiftUI 弹簧动画 | 封装成 `adaptiveGlass()` 修饰器 |
| 文件类型 | `net.daringfireball.markdown`（导入声明）+ `public.plain-text` | 见 `Sources/App/Info.plist` |

---

## 3. 工程结构

```
md-reader/
├── Package.swift              # SPM：MDPreviewCore 库 + 测试；依赖 swift-markdown（revision 锁定）
├── project.yml                # XcodeGen 配置 → 生成 MDPreview.xcodeproj（App 目标）
├── package_app.sh             # Release 构建 → ad-hoc 签名 → 打 DMG（DMG 走 Releases，不入库）
├── .github/workflows/ci.yml   # macos-15：swift build/test + xcodegen + xcodebuild
│
├── Sources/
│   ├── App/                           # Xcode App 目标（薄壳）
│   │   ├── MDPreviewApp.swift         # @main：DocumentGroup + .commands（视图 / 打印）
│   │   ├── Info.plist                 # 文档类型 / UTI 导入声明（CFBundleDevelopmentRegion = zh_CN）
│   │   └── Assets.xcassets            # AppIcon
│   │
│   └── MDPreviewCore/                 # 全部逻辑与 UI 都在这个库里
│       ├── Models/
│       │   ├── MarkdownDocument.swift # FileDocument：UTF-8 / UTF-16 / Latin-1 兜底解码
│       │   ├── MarkdownBlock.swift    # 渲染树块级枚举 + MarkdownListItem
│       │   ├── TOCItem.swift          # 大纲节点（可嵌套）
│       │   └── EditorState.swift      # @MainActor ObservableObject：viewMode / showTOC /
│       │                              #   targetScrollId / activeHeadingId
│       │                              #   + DocumentStats（CJK 按字、拉丁按词）
│       │                              #   + FocusedValue 桥（editorState / printableDocument）
│       ├── Resources/
│       │   └── Strings.swift          # enum L：面向用户字符串的唯一集中点（v1.3 国际化改造面）
│       ├── Engine/
│       │   ├── MarkdownASTParser.swift        # AST → [MarkdownBlock] + TOC + stats；NSCache(32) + prewarm
│       │   ├── AttributedStringBuilder.swift  # 行内 AST → AttributedString；==高亮== 正则；行内图片降级为占位符
│       │   ├── NativeSyntaxHighlighter.swift  # 代码块着色（阅读态）
│       │   ├── MarkdownSourceHighlighter.swift# 源码着色扫描器（编辑态，逐行 + 正则，跟踪围栏状态）
│       │   └── FileMonitor.swift              # DispatchSourceFileSystemObject 单文件监听（原子保存感知）
│       ├── System/
│       │   └── DocumentPrinter.swift  # 块边界分页 → 矢量 PDF（NSPrintOperation）+ PrintableDocument
│       └── UI/
│           ├── MainDocumentView.swift       # 主视图：SplitView 路由 + 防抖解析 + 任务回写 + 热重载 + 打印桥
│           ├── Glass/
│           │   ├── GlassAdapter.swift       # adaptiveGlass() / glassPill() 修饰器
│           │   └── LiquidGlassToolbar.swift # NativeUnifiedToolbar：principal 位分段模式切换器
│           ├── Reading/
│           │   ├── NativeReaderView.swift   # ScrollViewReader + LazyVStack；标题偏移 → 当前章节（异步写、防抖动）
│           │   ├── MarkdownBlockViews.swift # 各块视图 + MarkdownBlockDispatcher + 渲染上下文 Environment（Equatable）
│           │   └── TOCSidebarView.swift     # 大纲侧边栏：折叠 / 点击跳转 / 当前项高亮
│           ├── Editor/
│           │   └── NativeEditorView.swift   # scrollableTextView()；源码着色代码保留但默认关
│           └── Components/
│               └── FloatingStatusCapsule.swift # 右下角悬浮字数胶囊（悬停展开行数）
│
└── Tests/MDPreviewCoreTests/       # swift-testing：解析 / 统计 / 行内样式 / 源码着色 / FileMonitor / PDF 分页
```

> **仓库卫生**：工作区里出现过 Finder 复制产生的 `MDPreview 2.xcodeproj/`，属误入，应删除并在 `.gitignore` 收敛
> （`MDPreview*.xcodeproj/` 由 XcodeGen 生成，不应入库）。

---

## 4. 渲染管线

```
 .md 文本 (String)
      │
      ▼  MarkdownASTParser.parse(markdown:)              [NSCache 命中则直接返回]
 Document(parsing:options:[.parseBlockDirectives,.parseSymbolLinks])
      │
      ▼  逐 child 遍历 parseBlock(...)                    IDGen 按遍历序产出稳定 id（b0, b1, …）
      ├── Heading         → .heading(id:"heading-N", level, text, attributed)   ↘ 收集 TOCItem
      ├── Paragraph       → 仅图片段落 ⇒ .image；否则 .paragraph(attributed)
      ├── CodeBlock       → NativeSyntaxHighlighter.highlight → .codeBlock
      ├── BlockQuote      → 递归 parseBlock（collectTOC:false，引用内标题不进大纲）
      ├── Table           → 表头 / 对齐 / 行 全部 AttributedString
      ├── U/O/List        → parseListItem 递归；任一项有 checkbox ⇒ .taskList
      ├── ThematicBreak   → .thematicBreak
      └── HTMLBlock       → .html(raw)（当前按等宽灰字原样显示，不渲染）
      │
      ▼
 ParsedDocument { blocks: [MarkdownBlock], tocItems: [TOCItem]（stack 建层级）, stats: DocumentStats }
      │
      ├─▶ NativeReaderView   LazyVStack{ ForEach(blocks) { MarkdownBlockDispatcher } }  maxWidth 820
      │                       .textSelection(.enabled)（⚠️ 逐块，跨块不连续）
      │                       标题 GeometryReader → HeadingOffsetsKey → activeHeadingId → TOC 高亮
      └─▶ TOCSidebarView     OutlineGroup 式递归行；点击写 targetScrollId → ScrollViewReader.scrollTo
```

**解析触发**（`MainDocumentView.scheduleParse`）：

- 首次加载或 `text.utf8.count < 2048`：同步解析（命中缓存近乎零成本）。
- 大文档：`parseTask` 取消旧任务 → `Task.sleep(250ms)` 防抖 → `Task.detached` 后台解析 → 回主线程赋值。

**行内样式**（`AttributedStringBuilder`）：`Emphasis` / `Strong` / `Strikethrough` / `InlineCode`（等宽 + 底色）/
`Link`（`.linkColor` + 下划线）/ `SoftBreak`→空格 / `LineBreak`→换行 / `==文本==`→黄底（正则 `/==([^=\n]+)==/`，
不误伤 `a == b`）。**行内图片**目前降级为 ` 🖼️ [alt] ` 文本占位。

**任务回写**（`MainDocumentView.toggleTask`）：按 `sourceLine`（AST 提供的 0 基行号）定位，正则 `\[[ xX]\]`
就地替换为 `[x]` / `[ ]`，写回 `document.text`，触发重新解析。

---

## 5. 状态与交互

| 关注点 | 实现 |
| :-- | :-- |
| 视图模式 | `EditorState.viewMode`（`.reading` / `.editing` / `.split`）；工具栏分段控件直接绑定；菜单命令经 `FocusedValue(\.editorState)` |
| 大纲开合 | `EditorState.showTOC` ↔ `NavigationSplitViewVisibility` 在 `onChange` 里双向同步（避免视图更新期发状态） |
| 大纲联动 | 阅读区各标题上 `GeometryReader` 报 y 偏移（量化到 2pt）→ `HeadingOffsetsKey` → 取视口顶 ~80pt 内最后一个 → 用带 60ms sleep 的 `Task` 异步写 `activeHeadingId`（断开同帧回路，压掉 preference / publishing 警告） |
| 大纲跳转 | 点击写 `targetScrollId` → `NativeReaderView` 的 `ScrollViewReader` `scrollTo(anchor:.top)` 带动画 |
| 编辑器安全 | `updateNSView` 仅在**外部变更**且 `!isEditing && !hasMarkedText()` 时回灌；`textDidChange` 组字未提交不写回；回灌后钳制并恢复选区 |
| 编辑器着色 | `MarkdownSourceHighlighter` + `NSTextLayoutManager.renderingAttributesValidator` 已实现（显示层，不进 undo，120ms 防抖）但**默认关闭**（`NativeEditorView.sourceHighlightingEnabled = false`）；v1.3 偏好设置里接开关让用户开启 |
| 外部拖入 | `MainDocumentView.onDrop([.fileURL])` → `NSDocumentController.openDocument` |
| 热重载 | 每个 `fileURL` 一个 `FileMonitor`；无本地改动静默重载，冲突弹 `confirmationDialog`，文件被删显示横幅 |
| 字数统计 | `DocumentStats`：CJK（含假名 / 谚文）逐字计，拉丁按空白 / 标点切词，两者相加 |

**快捷键**：`⌘R` / `⌘E` / `⇧⌘E` 阅读 / 编辑 / 分屏；`⌘⌥S` 大纲开合；`⌘P` 打印 / `⌥⌘P` 导出 PDF；
`⌘N/O/S/⇧S` 文档操作（`DocumentGroup` 提供）；`⌘F` 仅编辑态（`NSTextView.usesFindBar`）。

---

## 6. 材质与排印

- **`adaptiveGlass(cornerRadius:isInteractive:tint:)`**：`#available(macOS 26)` 走 `.glassEffect(.regular[.tint][.interactive])`，
  否则 `ultraThinMaterial` + 细描边 + 轻投影。`glassPill()` = 圆角 100。
- 目前应用点：`FloatingStatusCapsule`（`glassPill`）、`TOCSidebarView`（`.ultraThinMaterial`）、工具栏分段控件（系统默认）。
- 排印：正文 `system size 14 / lineSpacing 5`；标题 `26/21/17/15/14/13`，H1·H2 带 `Divider`；代码 `system(size:13,.monospaced)`。
- 阅读区版心固定 `maxWidth 820`，水平 padding 32 —— 尚不可配置（偏好设置推迟到 v1.3）。
- 明暗跟随系统（未做主题覆盖）。

---

## 7. 构建与发布

| 环节 | 命令 / 文件 |
| :-- | :-- |
| 核心单测 | `swift test`（swift-testing；覆盖解析 / 统计 / 行内样式 / 源码着色 / `FileMonitor` / PDF 分页） |
| 生成工程 | `brew install xcodegen && xcodegen generate` → `MDPreview.xcodeproj` |
| 运行 / 预览 / 归档 | `open MDPreview.xcodeproj`（需完整版 Xcode，非 CLT） |
| 打包 DMG | `./package_app.sh`：Release 免签构建 → `ditto` 到 `/tmp` 清扩展属性 → ad-hoc 签名 → `hdiutil` 组 DMG |
| CI | `.github/workflows/ci.yml`：`macos-15` 跑 `swift build` / `swift test` / `xcodebuild`（`CODE_SIGNING_ALLOWED=NO`） |
| 分发 | DMG 不入库，作为 GitHub Release 附件；正式分发需 Developer ID + `notarytool` |

依赖策略：`swift-markdown` 上游无 semver tag，`Package.swift` 用 `revision` 锁 commit；`Package.resolved` 不入库
（在 Xcode 与命令行 SPM 之间 `originHash` 抖动无意义）。升级 = 改 revision → `swift package update` → 验回归。

---

## 8. 已知限制（Known Gaps）

| # | 限制 | 影响 | 计划 |
| :-- | :-- | :-- | :-- |
| G1 | 阅读区是逐块 `Text`，`.textSelection` 无法跨段落 / 跨列表连续框选；阅读态无 `⌘F` / 无原生查词 | 长文复制、检索体验差 | **v1.3**（与 i18n 合并做 TextKit 2 重写） |
| G2 | 无偏好设置：字号、行距、版心宽度、字体、主题都写死；明暗只跟随系统 | 无法适配阅读习惯 / 视力需求 | **v1.3**（一度在 v1.2 做过又推迟） |
| G3 | 编辑器无行号、无当前行高亮；源码着色已实现但默认关（`sourceHighlightingEnabled = false`），等 v1.3 偏好设置接开关。一度做过行号，与手搭 TextKit 2 栈冲突，已回退到 `scrollableTextView()` | 编辑长文定位稍弱 | v1.3（随阅读区重写） |
| G6 | 全部 UI 字符串仍是简体中文（已收敛进 `Strings.swift` 的 `L`）；`CFBundleDevelopmentRegion = zh_CN`；无 `.xcstrings` / `.lproj` | 只能服务中文用户 | **v1.3** |
| G7 | 无 Quick Look 缩略图 / 预览扩展 | Finder 空格键看到的是纯文本 | **v1.3** |
| G8 | 行内图片仅占位符；单段落多图按普通段落处理；无数学公式；HTML 块不渲染 | 富文档还原度不足 | v1.3+ |
| G9 | 无系统化无障碍（VoiceOver 标签 / Dynamic Type / 对比度）审查 | 可访问性欠缺 | **v1.3** |
| G10 | 代码着色为启发式逐行正则，跨行字符串 / 复杂语法会错色；语言有限；编辑器着色在非 TextKit 2 环境下静默失效 | 观感瑕疵 | 择机 |
| G11 | 编辑器源码着色：跨段围栏代码块只把 ``` 行本身变灰，块体不整体染色；超大文件按键时整篇重扫 | 长代码块观感、超大文件手感 | v1.3（随阅读区重写） |
| G12 | 热重载静默 reload 会把文档标记为「已编辑」；文件被删后 monitor 停止，直到再次保存才恢复 | 轻微 UX 瑕疵 | 择机 |
| G13 | PDF 分页在块边界断，单个超过一页的块（超长代码 / 大表）会溢出被 AppKit 默认切开 | 极端文档打印瑕疵 | v1.3（`NSAttributedString` 路径） |

**v1.2 已解决**：~~G4 无 PDF / 打印~~、~~G5 无外部修改监听~~。

---

## 9. 路线图（Roadmap）

> **v1.2 = 导出 PDF + 热重载 + 字符串收敛**（编辑器源码着色已写好但默认关）；
> **v1.3 = TextKit 2 阅读区重写 + 国际化 + 偏好设置**（都要动全部渲染 / 文案层，一起做）。
> 均不改 macOS 14 下限、不引入新第三方依赖。v1.2 已把面向用户字符串收敛进 `Strings.swift` 的 `L` 命名空间，
> 作为 v1.3 国际化的单一改造面。

> **范围调整记录**：v1.2 一度包含「偏好设置」与「编辑器行号 / 当前行高亮」。偏好设置推迟到 v1.3；
> 行号槽依赖手搭 TextKit 2 栈，与编辑区渲染冲突，已回退，编辑器恢复到 `scrollableTextView()` + 源码着色。

### v1.2 — ✅（已完成，未发布 / 本地 `v1.2` 分支）

| 项 | 落地内容 |
| :-- | :-- |
| **1.2.1 导出 PDF / 打印** (G4) | `DocumentPrinter` + `PrintableDocumentView`：逐块 `NSHostingView` 量高度 → 贪心装页 → `knowsPageRange` / `rectForPage` 在块边界断页 → `NSPrintOperation` 出矢量 PDF（强制浅色外观）。`⌘P` 系统打印面板（自带「存为 PDF」），`⌥⌘P`「导出为 PDF…」带保存面板；`CommandGroup(replacing: .printItem)`，经 `FocusedValue(\.printableDocument)` 取当前文档。 |
| **1.2.2 外部修改热重载** (G5) | `FileMonitor`（`DispatchSourceFileSystemObject`，`O_EVTONLY`，串行队列，150ms 合并，比对 inode 处理原子保存的 rename，回调派发到主线程）。`MainDocumentView` 每 `fileURL` 一个 monitor：无本地改动 → `NSFileCoordinator` 读盘后静默重载；本地 + 外部都改 → `confirmationDialog`（保留我的 / 用磁盘版本）；文件被删 → 内容区上方橙色横幅。 |
| **1.2.3 字符串收敛 + 警告清理** | 面向用户字符串迁进 `Strings.swift`（`enum L`）；`ViewMode` 显示名移到 `.title`。修掉 `HeadingOffsetsKey`「preference tried to update multiple times per frame」/「Publishing changes from within view updates」：标题偏移量化到 2pt、`MarkdownRenderContext` 加 `Equatable`、`activeHeadingId` 改带 60ms sleep 的 `Task` 异步写。 |
| **（隐藏）编辑器源码着色** | `MarkdownSourceHighlighter` 扫描器 + `renderingAttributesValidator` 施加逻辑已实现并有单测，但 `NativeEditorView.sourceHighlightingEnabled = false` 默认关闭（素色源码更简洁）。v1.3 偏好设置里接开关。 |

遗留见 G11–G13。

### v1.3 — TextKit 2 阅读区 + 国际化 + 偏好设置（目标：解决 G1、G2、G3、G6、G7、G9）

| 项 | 内容 | 关键取舍 / 风险 |
| :-- | :-- | :-- |
| **1.3.1 阅读区统一只读文本视图** (G1) | 混合式：`AttributedStringBuilder` 扩展出「AST → 单个 `NSAttributedString`（含段落样式 / 锚点属性）」，散文（标题 / 段落 / 列表 / 引用）并入只读 `NSTextView`（TextKit 2）实现跨块框选、阅读态 `⌘F`、原生查词；代码块 / 表格 / 图片 / 任务清单仍作「岛屿块」用 SwiftUI 覆盖视图或 `NSTextAttachment` 混排。 | **最大架构改动**。TOC 滚动联动 / 锚点跳转从 `ScrollViewReader` 迁到 `scrollRangeToVisible`；任务回写、代码复制等交互点要保留。先做纯散文文档再逐步纳入岛屿块。顺带给 1.2.2 的 PDF 做干净分页、给 1.2.1 的围栏整体染色兜底。 |
| **1.3.2 偏好设置** (G2、G3) | `AppPreferences`（`UserDefaults`）+ `Settings` 场景：字号、行距、版心宽度、正文 / 代码字体、明 / 暗 / 跟随系统、**编辑器源码着色开关**（接 `NativeEditorView.sourceHighlightingEnabled`，代码已就位）。字号 / 行距 / 版心作用于 1.3.1 的 `NSTextView` 段落样式（不再进 `AttributedString`，不需重解析）；编辑器行号 / 当前行高亮此时随新编辑区一并做。 | v1.2 里 typography 进 `AttributedString` + 缓存 key 的做法被证明笨重，1.3.1 的 `NSTextView` 用段落样式改字号是自然解法，所以绑在一起。 |
| **1.3.3 本地化基础设施** (G6) | 引入 **String Catalog（`.xcstrings`）**；把 `Strings.swift` 的 `L` 每个成员换成 `String(localized:)`（键即属性名），其余代码不动。提供 `en` + `zh-Hans`。`Info.plist`：`CFBundleDevelopmentRegion` 改 `en`，加 `CFBundleLocalizations`。`MDPreviewCore` 声明 `defaultLocalization` 与资源。 | v1.2 已把文案收敛到 `L` 一处，这里改造面单一。CI 加「无遗漏硬编码非 ASCII 字符串」守卫。 |
| **1.3.4 Locale 感知行为** | 阅读时长 / 数字 / 日期走 `.formatted()`；`DocumentStats` 词计规则保留（已按 CJK / 拉丁分流）。 | RTL 布局审查（`.environment(\.layoutDirection)`），至少不破版；完整 RTL 列 v1.3+。 |
| **1.3.5 文档类型 / 菜单 / 首启样例本地化** | UTI 描述、文档类型名、菜单项、错误提示全走目录；样例文档按语言给（`SampleDocument.md` / `SampleDocument_en.md`）。 | — |
| **1.3.6 Quick Look 扩展** (G7) | `QuickLook Preview Extension` + `Thumbnail Extension`，复用 `MDPreviewCore` 渲染，跟随系统语言。 | 独立 target，要进 `project.yml`；沙盒内存 / 时间预算紧。 |
| **1.3.7 无障碍 pass** (G9) | VoiceOver 标签（本地化后统一补）、尊重 Dynamic Type、对比度、键盘可达性。 | 与 1.3.3 合并推进，标签即字符串。 |
| **1.3.8 发布物** | 英文 `README.md` + `README.zh-Hans.md`；Release notes 双语；DMG 走 Developer ID 签名 + 公证。 | 需要 Apple Developer 账号；`package_app.sh` 已预留公证注释。 |

**v1.3 出口标准**：长文可跨块连续选择并复制、阅读态 `⌘F` 可用；系统语言切英文时全界面 / 菜单 / Quick Look / 样例文档均为英文，无残留中文；`en` / `zh-Hans` 均通过本地化守卫测试。

### v1.3 之后（候选，未排期）

- 行内图片真正渲染、单段多图、图片缩放 / 点击查看（G8）。
- 数学公式（考虑纯原生 `NSAttributedString` + 自绘，或谨慎评估轻量依赖）。
- HTML 块有限渲染。
- 代码高亮换成基于 tree-sitter / 更严谨的词法分析（G10）。
- 完整 RTL、更多语言（`ja` / `ko` / `de` / `fr`）。
- Markdown 方言开关（脚注、定义列表、`[[wiki]]` 链接）。

---

## 10. 术语

| 词 | 指 |
| :-- | :-- |
| **块 / block** | `MarkdownBlock` 枚举的一个 case，对应渲染树里的一个原生子视图 |
| **岛屿块 / island** | v1.2 术语：不并入连续正文流、单独用 SwiftUI 视图渲染的块（代码块 / 表格 / 图片 / 任务清单） |
| **锚点 / anchor** | 标题的稳定 id（`heading-N`），供 TOC 点击滚动与 URL 片段定位 |
| **回灌 / write-back** | 编辑器把外部对 `document.text` 的变更同步进 `NSTextView`（严格避开输入法组字与正在编辑态） |
| **本地化守卫** | v1.3 的 CI 检查：源码里不得出现面向用户的硬编码非 ASCII 字符串 |
