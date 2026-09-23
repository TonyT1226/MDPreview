# MDPreview 架构规范 (PROJECT_SPEC)

> **定位**：一款 100% 原生的 macOS Markdown 阅读 / 轻量编辑器。
> 不嵌 WebView、不跑 JS 引擎，`.md` 文本经 [`apple/swift-markdown`](https://github.com/apple/swift-markdown)
> 解析成 AST，再排成一个 `NSAttributedString` 放进只读 `NSTextView`（TextKit 1）；编辑器用 TextKit 2 (`NSTextView`)。
>
> 当前版本 **v1.3.0** · 运行需 **macOS 14+** · 构建需 **Xcode 16+** · MIT

本文件描述**当前实际实现**与**之后的候选计划**。已知未落地的能力集中在
[§8 已知限制](#8-已知限制known-gaps) 和 [§9 路线图](#9-路线图roadmap)，不要把路线图当成现状。

---

## 1. 设计原则

| 原则 | 含义 | 现状 |
| :-- | :-- | :-- |
| **零 WebKit** | 不加载 Web 渲染进程；冷启动快、内存低、滚动跟手 | ✅ 全链路原生 |
| **文档中心** | 依托 `DocumentGroup` + `FileDocument`，白拿多窗口 / 多标签 / 代理图标 / 版本快照 / 自动保存 | ✅ |
| **Finder 亲和** | `.md` 文件关联、拖入打开、空格键预览 | ✅ 关联 + 拖入 + Quick Look 预览 / 缩略图扩展 |
| **渐进材质** | macOS 26+ 用 Liquid Glass (`.glassEffect`)，14/15 回退 `.ultraThinMaterial` | ✅ 有统一抽象，覆盖面还小 |
| **解析与 UI 解耦** | 解析核心是独立 SPM 库，可单测、可给扩展复用 | ✅ `MDPreviewCore`，App 与两个 Quick Look 扩展共用 |

**非目标**（当前阶段明确不做）：所见即所得编辑、协同、插件系统、iOS / iPad 版、云同步。

---

## 2. 技术栈

| 层 | 选型 | 说明 |
| :-- | :-- | :-- |
| 语言 | **Swift 6**（`SWIFT_VERSION = 6.0`，严格并发） | 模型层普遍 `Sendable` |
| App / 窗口 | **SwiftUI `DocumentGroup` + `NavigationSplitView`** | 菜单命令经 `FocusedValue` 桥接到当前窗口 |
| 阅读态渲染 | **只读 `NSTextView`（TextKit 1）** + `ReaderRenderer` 排出的整篇 `NSAttributedString` | 代码块 / 引用 / 标题线用 `NSTextBlock`，表格用 `NSTextTable`（两者只有 TextKit 1 支持） |
| 编辑态 | **TextKit 2**：`NSTextView.scrollableTextView()`（`NSTextLayoutManager`） | 纯文本、等宽、关闭智能标点 / 拼写 |
| Markdown 解析 | **`apple/swift-markdown`**（cmark-gfm） | 用 `revision` 精确锁定 commit，不发 semver |
| 代码高亮 | 自研 `NativeSyntaxHighlighter`（逐行 + 正则分词） | 7 种语言 + 通用兜底 |
| 本地化 | **String Catalog**（`Localizable.xcstrings`，`en` + `zh-Hans`） | `L` 的键即属性名，英文在 `defaultValue` |
| 偏好设置 | `@AppStorage` + `Settings` 场景 | 键集中在 `PrefKey` |
| Finder 预览 | Quick Look 预览扩展（view-based）+ 缩略图扩展 | 沙盒，复用 `ReaderRenderer` |
| 材质 / 动效 | `glassEffect` (macOS 26) / `ultraThinMaterial` 回退 + SwiftUI 弹簧动画 | 封装成 `adaptiveGlass()` 修饰器 |
| 文件类型 | `net.daringfireball.markdown`（导入声明）+ `public.plain-text` | 见 `Sources/App/Info.plist` |

---

## 3. 工程结构

```
md-reader/
├── Package.swift              # SPM：MDPreviewCore 库（defaultLocalization en，含 xcstrings 资源）+ 测试
├── project.yml                # XcodeGen：App + 两个 Quick Look 扩展 → MDPreview.xcodeproj
├── package_app.sh             # Release 构建 → 扩展带 entitlements 签名 → 签 App → 打 DMG
├── .github/workflows/ci.yml   # macos-15：swift build/test + xcodegen + xcodebuild
│
├── Sources/
│   ├── App/                           # App 目标（薄壳）
│   │   ├── MDPreviewApp.swift         # @main：DocumentGroup + Settings + .commands（视图 / 缩放 / 打印）
│   │   ├── Info.plist                 # 文档类型 / UTI；CFBundleDevelopmentRegion = en，CFBundleLocalizations
│   │   ├── InfoPlist.xcstrings        # 文档类型名的中文
│   │   └── Assets.xcassets
│   ├── QuickLookPreview/              # 空格预览扩展：PreviewViewController（QLPreviewingController）
│   ├── QuickLookThumbnail/            # 缩略图扩展：ThumbnailProvider（QLThumbnailProvider）
│   │
│   └── MDPreviewCore/
│       ├── Models/                    # MarkdownDocument / MarkdownBlock / TOCItem / EditorState(+DocumentStats)
│       ├── Preferences/
│       │   ├── AppPreferences.swift   # PrefKey、ReaderStyle（排版参数）、FontZoom、ThemeController
│       │   └── PreferencesView.swift  # Settings 窗口
│       ├── Resources/
│       │   ├── Strings.swift          # enum L：全部界面文字
│       │   └── Localizable.xcstrings  # en + zh-Hans
│       ├── Engine/
│       │   ├── MarkdownASTParser.swift        # AST → [MarkdownBlock] + TOC + stats；NSCache(32) + prewarm
│       │   ├── AttributedStringBuilder.swift  # 行内 AST → 语义 AttributedString（intent + AppKit 动态色，不定字体）
│       │   ├── NativeSyntaxHighlighter.swift  # 代码块着色（只上色）
│       │   ├── ReaderRenderer.swift           # [MarkdownBlock] + ReaderStyle → NSAttributedString + 标题位置表
│       │   ├── MarkdownSourceHighlighter.swift# 编辑器源码着色扫描器
│       │   └── FileMonitor.swift              # 单文件监听（热重载）
│       ├── System/
│       │   ├── DocumentPrinter.swift  # 打印 / 导出 PDF：同一渲染器 → 离屏 ReaderTextView → NSPrintOperation
│       │   └── QuickLookSupport.swift # 给扩展用的预览视图 / 缩略图绘制入口
│       └── UI/
│           ├── MainDocumentView.swift       # 视图路由 + 防抖解析 + 任务回写 + 热重载 + 打印桥
│           ├── Glass/                       # adaptiveGlass()、工具栏分段控件
│           ├── Reading/
│           │   ├── NativeReaderView.swift   # SwiftUI 外壳 + ReaderTextRepresentable + ReaderTextView
│           │   ├── RemoteImageCache.swift   # 远程图片缓存，加载完通知重排
│           │   └── TOCSidebarView.swift
│           ├── Editor/
│           │   ├── NativeEditorView.swift   # scrollableTextView()；字号 / 源码着色 / 行号由偏好控制
│           │   └── LineNumberRulerView.swift# TextKit 2 行号栏
│           └── Components/FloatingStatusCapsule.swift
│
└── Tests/MDPreviewCoreTests/       # swift-testing：解析 / 渲染 / 阅读视图交互 / 本地化 / 源码着色 / FileMonitor / 打印
                                    # + 手动快照（MDP_SNAPSHOT_DIR）与性能探针（MDP_PERF）
```

---

## 4. 渲染管线

```
 .md 文本
   │  MarkdownASTParser.parse(markdown:)          [NSCache 命中直接返回]
   ▼
 ParsedDocument { blocks: [MarkdownBlock], tocItems, stats }
   │  块里的行内内容是「语义」AttributedString：
   │  inlinePresentationIntent（强调 / 加粗 / 代码 / 删除线）+ link + AppKit 动态色（高亮底色、代码着色）
   │
   │  ReaderRenderer(style: ReaderStyle, baseURL:, imageProvider:).render(blocks)
   ▼
 RenderedDocument { text: NSAttributedString, headings: [(id, 字符位置)] }
   │
   ├─▶ ReaderTextView（只读 NSTextView，TextKit 1）   阅读区 / Quick Look 预览
   ├─▶ 离屏 ReaderTextView（浅色、贴满纸宽）         打印 / 导出 PDF
   └─▶ NSLayoutManager 直接绘制                       Quick Look 缩略图
```

**排版规则**（`ReaderRenderer`）：

- 字体、字号、行距全部在这里按 `ReaderStyle` 定，解析结果里不带字体，所以改偏好不需要重新解析。
- 每个段落一个段落样式。块间距用 `paragraphSpacing`；带 `NSTextBlock` 的块用 block 的 margin。
- 代码块：满宽 `NSTextBlock`，底色 + 细边框 + 12pt 内边距，等宽字体。
- 引用：满宽 `NSTextBlock`，左边框 3pt 强调色，文字次要色；内部块递归渲染，`textBlocks` 由外到内叠加。
- H1 / H2：带下边框的 `NSTextBlock`。分割线：只有下边框的空 block。
- 表格：`NSTextTable`，每个单元格一个 `NSTextTableBlock` 段落；表头底色 + 隔行底色，列对齐来自 Markdown。
- 列表：标记（`•` / 序号 / 复选框）+ 制表符，`headIndent` 让折行对齐正文；嵌套时缩进累加。
- 任务复选框：SF Symbol 附件，带 `.mdTaskSourceLine` / `.mdTaskChecked` 自定义属性。
- 图片：`FittingImageAttachment`，超过行宽时等比缩小；本地图片同步读，远程图片走 `RemoteImageCache`，
  加载完发通知让阅读区重排；失败显示占位文字。
- 颜色都是动态色；带透明度的颜色包一层 provider（直接 `withAlphaComponent` 会按当时外观定死）。
  `NSTextBlock` 画边框时忽略透明度，所以边框用不透明灰。

**解析触发**（`MainDocumentView.scheduleParse`）：小文档同步解析；大文档 250ms 防抖后后台解析。
阅读区在 `blocks` / 样式 / baseURL 任一变化时重排整篇，保持滚动位置和选区；只强制排到原视口底部。
（160KB 文档：解析约 0.11s，生成属性串约 0.09s。）

**任务回写**（`MainDocumentView.toggleTask`）：阅读区 `mouseDown` 命中复选框附件 → 按源行号用正则
`\[[ xX]\]` 就地替换 → 写回 `document.text` → 重新解析。

---

## 5. 状态与交互

| 关注点 | 实现 |
| :-- | :-- |
| 视图模式 | `EditorState.viewMode`；工具栏分段控件直接绑定；菜单命令经 `FocusedValue(\.editorState)`，放在系统「显示 / View」菜单里 |
| 大纲开合 | `EditorState.showTOC` ↔ `NavigationSplitViewVisibility` 在 `onChange` 里双向同步 |
| 大纲跳转 | 点击写 `targetScrollId` → 阅读区按标题字符位置算出行矩形 → 滚动剪辑视图（减少动态效果时不做动画）→ 把 `targetScrollId` 复位，同一项可再点 |
| 大纲联动 | 监听剪辑视图 `boundsDidChange`：视口顶部往下 80pt 处的字符之前最后一个标题即当前章节，下一轮 runloop 写 `activeHeadingId` |
| 链接 | `NSTextViewDelegate.clickedOnLink`：`#锚点` 按 GitHub 规则生成的 slug 找标题；相对路径基于文档目录解析，`.md` 用本 App 打开，其他交给系统 |
| 查找 | 阅读区与编辑器都是 `NSTextView`，`usesFindBar`；`⌘F` 走系统菜单 |
| 偏好设置 | `@AppStorage`；阅读区读 `ReaderStyle`，编辑器读字号 / 着色 / 行号；主题由 `ThemeController` 设 `NSApp.appearance` |
| 编辑器安全 | `updateNSView` 仅在外部变更且不在编辑、不在组字时回灌；回灌后钳制并恢复选区 |
| 编辑器着色 | `renderingAttributesValidator`（显示层，不进 undo）；偏好开关装上 / 卸下 |
| 编辑器行号 | `LineNumberRulerView`：只读 `textLayoutManager`（碰 `layoutManager` 会退回 TextKit 1）；按源码行编号，光标行加深 |
| 热重载 | 每个 `fileURL` 一个 `FileMonitor`；无本地改动静默重载，冲突时询问，文件被删显示横幅 |
| 字数统计 | CJK 逐字计，拉丁按词计 |

---

## 6. 材质、排印与无障碍

- `adaptiveGlass()`：macOS 26 用 `.glassEffect`，否则 `ultraThinMaterial`。用在状态胶囊、大纲侧边栏。
- 排印默认值（`ReaderStyle.default`）：正文 15pt、行高倍数 1.45、版心 820pt、系统字体。
  标题按正文的 1.8 / 1.45 / 1.2 / 1.05 / 1.0 / 0.93 倍；代码约 0.88 倍等宽体。
- 字体可选系统 / 衬线 / 等宽。衬线体用 New York，中文回退到宋体（显式 cascade list）。
- 版心：`ReaderTextView` 按视图宽度算左右边距，窗口比版心宽时居中，最窄 32pt。
- 主题：跟随系统 / 浅色 / 深色，改 `NSApp.appearance`。
- 无障碍：阅读区与编辑器本身是 `NSTextView`，VoiceOver 可逐行读；大纲项读作「N 级标题，标题」，
  折叠按钮、视图模式切换、字数胶囊都有标签；复选框图片带描述。
  「增强对比度」下边框与代码底色加深；「减少动态效果」下视图切换、大纲、滚动都不做动画。
  macOS 没有 Dynamic Type，字号由偏好和 `⌘=` / `⌘-` 控制。

---

## 7. 构建与发布

| 环节 | 命令 / 文件 |
| :-- | :-- |
| 核心单测 | `swift test`（swift-testing；解析 / 渲染 / 阅读视图交互 / 本地化 / 源码着色 / `FileMonitor` / 打印）。仓库在 iCloud 目录时加 `--scratch-path` 指到别处 |
| 生成工程 | `brew install xcodegen && xcodegen generate` → `MDPreview.xcodeproj` |
| 运行 / 预览 / 归档 | `open MDPreview.xcodeproj`（需完整版 Xcode，非 CLT） |
| 打包 DMG | `./package_app.sh`：Release 免签构建 → `ditto` 到 `/tmp` 清扩展属性 → 两个扩展带 entitlements ad-hoc 签名 → 签 App → `hdiutil` 组 DMG |
| CI | `.github/workflows/ci.yml`：`macos-15` 跑 `swift build` / `swift test` / `xcodebuild`（`CODE_SIGNING_ALLOWED=NO`） |
| 分发 | DMG 不入库，作为 GitHub Release 附件；正式分发需 Developer ID + `notarytool` |

依赖策略：`swift-markdown` 上游无 semver tag，`Package.swift` 用 `revision` 锁 commit；`Package.resolved` 不入库
（在 Xcode 与命令行 SPM 之间 `originHash` 抖动无意义）。升级 = 改 revision → `swift package update` → 验回归。

---

## 8. 已知限制（Known Gaps）

| # | 限制 | 影响 | 计划 |
| :-- | :-- | :-- | :-- |
| G8 | 行内图片仅占位符；单段落多图按普通段落处理；无数学公式；HTML 块按等宽灰字原样显示 | 富文档还原度不足 | 以后 |
| G10 | 代码着色为启发式逐行正则，跨行字符串 / 复杂语法会错色；语言有限 | 观感瑕疵 | 择机 |
| G11 | 编辑器源码着色：跨段围栏代码块只把 ``` 行本身变灰；超大文件按键时整篇重扫 | 长代码块观感、超大文件手感 | 择机 |
| G12 | 热重载静默 reload 会把文档标记为「已编辑」；文件被删后 monitor 停止，直到再次保存才恢复 | 轻微 UX 瑕疵 | 择机 |
| G14 | 代码块不横向滚动，长行折行显示；`NSTextBlock` 没有圆角 | 与 v1.2 的 SwiftUI 版观感不同 | 接受 |
| G15 | 每次文本变化都重排整篇属性串；超大文档（数百 KB）在分屏模式下打字时阅读区更新有延迟 | 超大文档手感 | 择机做增量 |
| G16 | Quick Look 扩展在沙盒里没有网络权限，远程图片显示占位；相对路径图片能否读到取决于系统授予的访问范围 | 预览图片不全 | 接受 |
| G17 | 核心库静态链接进 App 和两个扩展，DMG 从约 3.6MB 变成约 7.5MB | 体积 | 可改成动态框架 |
| G18 | 没有公证：DMG 仍是 ad-hoc 签名 | 首次打开要右键 › 打开 | 需要 Developer ID |

**v1.3 已解决**：~~G1 阅读区不能跨块选择 / 无 ⌘F~~、~~G2 无偏好设置~~、~~G3 编辑器无行号~~、
~~G6 只有中文~~、~~G7 无 Quick Look~~、~~G9 无障碍~~、~~G13 超长块打印溢出~~（打印改由 `NSTextView` 按行分页）。
**v1.2 已解决**：~~G4 无 PDF / 打印~~、~~G5 无外部修改监听~~。

---

## 9. 路线图（Roadmap）

### v1.3 — ✅ 阅读区重写 + 国际化 + 偏好设置

| 项 | 落地内容 |
| :-- | :-- |
| **1.3.1 阅读区** (G1) | `ReaderRenderer` 把整篇文档排成一个 `NSAttributedString`，放进只读 `ReaderTextView`。跨块选择、`⌘F`、查词、链接点击都由 `NSTextView` 提供。计划里的「岛屿块」混排没有做：代码块 / 表格 / 图片 / 复选框全部进同一段文本（`NSTextBlock` / `NSTextTable` / 附件），因此用 TextKit 1 而不是 TextKit 2。代码块的「复制」按钮去掉，改用选中 + `⌘C`。 |
| **1.3.2 偏好设置** (G2、G3) | `Settings` 窗口：字体、字号、行距、版心宽度、主题、编辑器行号、源码着色；`⌘=` / `⌘-` / `⌘0`；「恢复默认设置」。编辑器行号用 TextKit 2 的 `NSRulerView`，当前行只在行号上加深，没有整行底色（那需要换掉 `scrollableTextView()`，v1.2 试过，会冲突）。 |
| **1.3.3 本地化** (G6) | `Localizable.xcstrings`（61 条，英文计数带复数规则）；`Info.plist` 开发区域改 `en` 并声明 `en` / `zh-Hans`，系统菜单随之切换；文档类型名走 `InfoPlist.xcstrings`。自有的「视图」菜单并进系统「显示 / View」菜单（英文下原来会出现两个 View）。测试检查 catalog 完整、`Sources/` 无硬编码中日韩字符串。 |
| **1.3.4 Locale 行为** | 数字格式沿用 `%lld`；没有做 RTL 审查。 |
| **1.3.5 文档类型 / 菜单本地化** | 已做。样例文档按语言区分没有做（`SampleDocument.md` 只是仓库里的测试文档，App 首启不打开它）。 |
| **1.3.6 Quick Look** (G7) | 两个沙盒扩展：空格预览（`QLPreviewingController`，可滚动、可选择）和缩略图（文档开头画成一页纸）。都复用 `ReaderRenderer`。 |
| **1.3.7 无障碍** (G9) | 见 §6。 |
| **1.3.8 发布物** | `README.md`（英文）+ `README.zh-Hans.md`。签名公证未做（没有 Developer ID）。 |

### v1.3 之后（候选，未排期）

- 行内图片真正渲染、单段多图、图片点击查看（G8）。
- 数学公式（考虑纯原生 `NSAttributedString` + 自绘，或谨慎评估轻量依赖）。
- HTML 块有限渲染。
- 代码高亮换成更严谨的词法分析（G10）。
- 增量重排（G15）；核心库改动态框架（G17）。
- RTL 审查、更多语言（`ja` / `ko` / `de` / `fr`）。
- Markdown 方言开关（脚注、定义列表、`[[wiki]]` 链接）。

---

## 10. 术语

| 词 | 指 |
| :-- | :-- |
| **块 / block** | `MarkdownBlock` 枚举的一个 case，渲染成属性串里的一个或多个段落 |
| **排版参数 / ReaderStyle** | 字号、行距、版心、字体；渲染器的输入，来自偏好设置 |
| **锚点 / anchor** | 标题的稳定 id（`heading-N`），供 TOC 点击滚动与 URL 片段定位 |
| **回灌 / write-back** | 编辑器把外部对 `document.text` 的变更同步进 `NSTextView`（严格避开输入法组字与正在编辑态） |
| **本地化守卫** | `HardcodedStringGuard` 测试：`Sources/` 里（注释、`#if DEBUG`、`Strings.swift` 除外）不得出现含中日韩字符的字符串字面量 |
