import AppKit
import Markdown

/// 将 swift-markdown 的行内 AST 节点递归转换为 AttributedString。
///
/// 只记录**语义**：强调 / 代码 / 删除线走 `inlinePresentationIntent`，颜色用 AppKit 动态色。
/// 字体、字号、行距不在这里定 —— 由 `ReaderRenderer` 按偏好统一排版。
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
            attr.inlinePresentationIntent = (attr.inlinePresentationIntent ?? []).union(.code)
            attr.appKit.backgroundColor = NSColor.dynamic(light: NSColor(white: 0, alpha: 0.06),
                                                          dark: NSColor(white: 1, alpha: 0.12))
            return attr

        case let strikethrough as Markdown.Strikethrough:
            var inner = build(from: strikethrough)
            inner.inlinePresentationIntent = (inner.inlinePresentationIntent ?? []).union(.strikethrough)
            return inner

        case let link as Markdown.Link:
            var inner = build(from: link)
            if let dest = link.destination, let url = URL(string: dest) {
                inner.link = url
            }
            return inner

        case let image as Markdown.Image:
            let altText = image.plainText.isEmpty ? (image.title ?? L.imageGenericAlt) : image.plainText
            var attr = AttributedString(" 🖼️ [\(altText)] ")
            attr.appKit.foregroundColor = .secondaryLabelColor
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
            attr.appKit.foregroundColor = .secondaryLabelColor
            return attr

        case let symbolLink as Markdown.SymbolLink:
            var attr = AttributedString(symbolLink.destination ?? "")
            attr.inlinePresentationIntent = .code
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

    /// 解析 `==文本==` 高亮句法（正则逐段匹配，正文中的 `a == b` 不受影响）
    public static func parseHighlightSyntax(in string: String) -> AttributedString {
        guard string.contains("==") else { return AttributedString(string) }

        let pattern = /==([^=\n]+)==/
        var result = AttributedString()
        var cursor = string.startIndex

        for match in string.matches(of: pattern) {
            if match.range.lowerBound > cursor {
                result.append(AttributedString(String(string[cursor..<match.range.lowerBound])))
            }
            var highlighted = AttributedString(String(match.1))
            highlighted.appKit.backgroundColor = NSColor.dynamic(.systemYellow, alpha: 0.38)
            result.append(highlighted)
            cursor = match.range.upperBound
        }
        if cursor < string.endIndex {
            result.append(AttributedString(String(string[cursor...])))
        }
        return result
    }
}
