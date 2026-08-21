import SwiftUI
import Markdown

/// 将 swift-markdown 的行内 AST 节点递归转换为原生 AttributedString (支持 GFM 与 ==高亮== 句法)
public struct AttributedStringBuilder: Sendable {

    public static func build(from markup: any Markup) -> AttributedString {
        var result = AttributedString()

        for child in markup.children {
            result.append(buildSingle(from: child))
        }

        return result
    }

    public static func buildSingle(from markup: any Markup) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            return parseHighlightSyntax(in: text.string)

        case let emphasis as Markdown.Emphasis:
            var inner = build(from: emphasis)
            inner.inlinePresentationIntent = (inner.inlinePresentationIntent ?? []).union(.emphasized)
            return inner

        case let strong as Markdown.Strong:
            var inner = build(from: strong)
            inner.inlinePresentationIntent = (inner.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
            return inner

        case let inlineCode as Markdown.InlineCode:
            var attr = AttributedString(inlineCode.code)
            attr.font = .system(size: 13, weight: .medium, design: .monospaced)
            attr.inlinePresentationIntent = (attr.inlinePresentationIntent ?? []).union(.code)
            attr.backgroundColor = Color(nsColor: .separatorColor).opacity(0.3)
            return attr

        case let strikethrough as Markdown.Strikethrough:
            var inner = build(from: strikethrough)
            inner.inlinePresentationIntent = (inner.inlinePresentationIntent ?? []).union(.strikethrough)
            return inner

        case let link as Markdown.Link:
            var inner = build(from: link)
            if let dest = link.destination, let url = URL(string: dest) {
                inner.link = url
                inner.underlineStyle = .single
                inner.foregroundColor = Color(nsColor: .linkColor)
            }
            return inner

        case let image as Markdown.Image:
            let altText = image.plainText.isEmpty ? (image.title ?? "图片") : image.plainText
            var attr = AttributedString(" 🖼️ [\(altText)] ")
            attr.foregroundColor = Color(nsColor: .secondaryLabelColor)
            if let dest = image.source, let url = URL(string: dest) {
                attr.link = url
            }
            return attr

        case _ as Markdown.SoftBreak:
            return AttributedString(" ")

        case _ as Markdown.LineBreak:
            return AttributedString("\n")

        case let inlineHTML as Markdown.InlineHTML:
            var attr = AttributedString(inlineHTML.rawHTML)
            attr.foregroundColor = Color(nsColor: .secondaryLabelColor)
            return attr

        case let symbolLink as Markdown.SymbolLink:
            var attr = AttributedString(symbolLink.destination ?? "")
            attr.font = .system(.body, design: .monospaced)
            return attr

        default:
            var fallback = AttributedString()
            for child in markup.children {
                fallback.append(buildSingle(from: child))
            }
            if fallback.characters.isEmpty {
                return parseHighlightSyntax(in: markup.format())
            }
            return fallback
        }
    }

    /// 解析 `==文本==` 高亮句法
    public static func parseHighlightSyntax(in string: String) -> AttributedString {
        guard string.contains("==") else {
            return AttributedString(string)
        }

        var result = AttributedString()
        let components = string.components(separatedBy: "==")
        
        // 奇数个组件意味着有成对的 ==
        for (index, component) in components.enumerated() {
            if component.isEmpty { continue }
            
            if index % 2 == 1 && index < components.count - (components.count % 2 == 0 ? 1 : 0) {
                // 位于 == 内部的内容 -> 施加高亮背景
                var highlighted = AttributedString(component)
                highlighted.backgroundColor = Color(nsColor: .systemYellow).opacity(0.38)
                highlighted.foregroundColor = .primary
                result.append(highlighted)
            } else {
                // 普通文本
                result.append(AttributedString(component))
            }
        }

        return result
    }
}
