# macOS 27 原生极简 Markdown 阅读器设计规范

> 这是一个专为 **MDPreview** 准备的综合特性测试文档。包含了排版、数学、表格、代码、列表与任务项。

---

## 1. 排版与富文本样式

在 macOS 纯原生体系下，文本排版基于 **Apple System Typography (SF Pro / New York / SF Mono)**。

* **加粗强调**：用于凸显关键特性与指标。
* *斜体修饰*：用于术语引用与次要说明。
* ==高亮重点标记==：支持 `==文本==` 高亮句法，渲染为 macOS 原生柔和荧光黄色。
* ~~删除线文本~~：用于标记废弃方案。
* `行内代码样式`：带有轻微半透明底衬与圆角。
* [超链接导航](https://apple.com)：原生系统色彩与下划线交互。

---

## 2. 代码块与语法高亮

以下是 Swift 原生代码块，内置一键复制及 Xcode 语法着色：

```swift
import SwiftUI
import Markdown

struct LiquidGlassDocumentView: View {
    @State private var isReadingMode: Bool = true
    
    var body: some View {
        VStack {
            Text("Native macOS Experience")
                .font(.system(.title, design: .rounded))
        }
        .adaptiveGlass(cornerRadius: 16, isInteractive: true)
    }
}
```

---

## 3. 表格支持 (SwiftUI Grid 渲染)

| 架构维度 | 传统 WebKit 方案 | MDPreview 纯原生方案 |
| :--- | :--- | :--- |
| **内存占用** | 80MB ~ 150MB | **< 15MB** |
| **冷启动耗时** | 150ms ~ 300ms | **< 30ms** |
| **渲染引擎** | Safari / WebKit 进程 | **apple/swift-markdown + TextKit 2** |
| **设计契合度** | HTML/CSS 模拟 | **100% macOS HIG & Liquid Glass** |

---

## 4. 任务清单 (Task Lists)

- [x] 搭建 Swift 6 模块化项目结构
- [x] 接入官方 swift-markdown AST 解析引擎
- [x] 实现 Liquid Glass 统一流体工具栏
- [x] 集成 TextKit 2 原生 NSTextView 编辑器
- [ ] 导出矢量 PDF 与打印支持
- [ ] Finder Quick Look 快速预览插件

---

## 5. 引用与说明

> “简约至极，是对复杂事物的终极掌控。”
> 
> 纯原生应用不仅拥有极致的性能，更能给用户带来无可替代的原生平台归属感。
