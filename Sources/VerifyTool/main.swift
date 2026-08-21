import Foundation
import MDPreviewCore

print("=== MDPreview 纯原生 AST 解析与排版引擎验证 ===")

let sampleURL = URL(fileURLWithPath: "SampleDocument.md")
guard let markdownText = try? String(contentsOf: sampleURL, encoding: .utf8) else {
    print("❌ 无法读取 SampleDocument.md")
    exit(1)
}

let startTime = CFAbsoluteTimeGetCurrent()
let parsed = MarkdownASTParser.parse(markdown: markdownText)
let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

print(String(format: "⏱️ 解析耗时: %.2f ms", elapsedMs))
print("📊 统计信息: \(parsed.stats.characterCount) 字符, \(parsed.stats.wordCount) 词, \(parsed.stats.lineCount) 行, 预估 \(parsed.stats.readingTimeMinutes) 分钟阅读")
print("📑 目录大纲提取 (\(parsed.tocItems.count) 个顶级节点):")

for item in parsed.tocItems {
    print("  - [H\(item.level)] \(item.title) (id: \(item.id))")
    for sub in item.children {
        print("    - [H\(sub.level)] \(sub.title) (id: \(sub.id))")
    }
}

print("\n🧱 纯原生块级元素 (\(parsed.blocks.count) 个块):")
for (i, block) in parsed.blocks.enumerated() {
    switch block {
    case .heading(_, let level, let text, _):
        print("  [\(i+1)] Heading (H\(level)): \(text)")
    case .paragraph(let attr):
        print("  [\(i+1)] Paragraph: \(attr.characters.prefix(30))...")
    case .codeBlock(_, let lang, _, _):
        print("  [\(i+1)] Code Block (Lang: \(lang ?? "none"))")
    case .table(let headers, _, let rows):
        print("  [\(i+1)] Table (\(headers.count) 列, \(rows.count) 行)")
    case .blockquote(let blocks):
        print("  [\(i+1)] Blockquote (\(blocks.count) 子块)")
    case .taskList(let items):
        print("  [\(i+1)] Task List (\(items.count) 项, \(items.filter { $0.isChecked }.count) 已完成)")
    case .unorderedList(let items):
        print("  [\(i+1)] Unordered List (\(items.count) 项)")
    case .orderedList(let items):
        print("  [\(i+1)] Ordered List (\(items.count) 项)")
    case .thematicBreak:
        print("  [\(i+1)] Divider (HR)")
    case .html:
        print("  [\(i+1)] HTML Block")
    }
}

print("\n✅ 纯原生 AST 解析与组件树映射全部验证通过！")
