import Foundation

/// 一次文本替换：把 `range` 换成 `replacement`，之后选区设为 `selection`（替换后的坐标）
public struct TextEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }

    /// 把编辑应用到字符串上（测试用）
    public func applied(to text: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }
}

/// 编辑器里的 Markdown 辅助操作：快捷格式、列表续写、缩进。
///
/// 只做「给定文本和选区 → 算出一次替换」，不碰视图，便于单测。
/// 返回 nil 表示不介入，交给 NSTextView 的默认行为。
/// 所有位置都是 UTF-16 偏移（与 NSString / NSTextView 一致）。
public enum MarkdownEditing {

    public enum InlineStyle: Sendable {
        case bold, italic, code

        var marker: Character {
            switch self {
            case .bold, .italic: return "*"
            case .code: return "`"
            }
        }

        var width: Int { self == .bold ? 2 : 1 }
    }

    /// 缩进单位：4 个空格。对 `- ` 和 `1. ` 两种列表都能构成合法的嵌套（CommonMark）。
    public static let indentUnit = "    "

    // MARK: - 快捷格式

    /// 加粗 / 斜体 / 行内代码：有选区则包裹，已包裹则去掉；无选区则插入一对标记，光标放中间
    public static func toggleInline(_ style: InlineStyle, text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        let m = style.marker
        let unit = m.utf16.count

        // 选区外侧紧挨着的同种标记个数
        let before = run(of: m, in: ns, endingAt: selection.location)
        let after = run(of: m, in: ns, startingAt: NSMaxRange(selection))
        let outside = min(before, after)
        if hasStyle(style, run: outside) {
            // 去掉外侧标记
            let w = style.width * unit
            let range = NSRange(location: selection.location - w, length: selection.length + 2 * w)
            let inner = ns.substring(with: selection)
            return TextEdit(range: range, replacement: inner,
                            selection: NSRange(location: selection.location - w, length: selection.length))
        }

        // 选中的文字自身带着标记（如选中了 **x**）
        if selection.length > 0 {
            let selected = ns.substring(with: selection) as NSString
            let lead = run(of: m, in: selected, startingAt: 0)
            let trail = run(of: m, in: selected, endingAt: selected.length)
            let inside = min(lead, trail)
            let w = style.width * unit
            if hasStyle(style, run: inside), selected.length > 2 * w {
                let inner = selected.substring(with: NSRange(location: w, length: selected.length - 2 * w))
                return TextEdit(range: selection, replacement: inner,
                                selection: NSRange(location: selection.location, length: (inner as NSString).length))
            }
        }

        // 包裹
        let marker = String(repeating: String(m), count: style.width)
        let w = (marker as NSString).length
        let inner = ns.substring(with: selection)
        return TextEdit(range: selection, replacement: marker + inner + marker,
                        selection: NSRange(location: selection.location + w, length: selection.length))
    }

    /// 链接：选中普通文字 → `[文字]()` 光标进括号；选中网址 → `[](网址)` 光标进方括号；无选区 → `[]()`
    public static func insertLink(text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        let selected = ns.substring(with: selection)
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeURL(trimmed) {
            return TextEdit(range: selection, replacement: "[](\(trimmed))",
                            selection: NSRange(location: selection.location + 1, length: 0))
        }
        let replacement = "[\(selected)]()"
        let caret = selection.location + (replacement as NSString).length - 1
        return TextEdit(range: selection, replacement: replacement,
                        selection: NSRange(location: selection.length == 0 ? selection.location + 1 : caret, length: 0))
    }

    // MARK: - 列表续写

    /// 回车：在列表项里续写下一个标记；空列表项上回车则清掉标记（退出列表）
    public static func newline(text: String, selection: NSRange) -> TextEdit? {
        guard selection.length == 0 else { return nil }
        let ns = text as NSString
        let caret = selection.location
        let lineRange = contentLineRange(in: ns, at: caret)
        let line = ns.substring(with: lineRange)
        guard let item = ListItemPrefix(line: line) else { return nil }
        // 光标在标记之前（或标记中间）时不介入
        guard caret - lineRange.location >= item.length else { return nil }
        guard !isInsideFence(ns, before: lineRange.location) else { return nil }

        let body = (line as NSString).substring(from: item.length)
        if body.trimmingCharacters(in: .whitespaces).isEmpty {
            // 空列表项：去掉标记，留下空行
            return TextEdit(range: lineRange, replacement: "",
                            selection: NSRange(location: lineRange.location, length: 0))
        }

        let next = "\n" + item.nextPrefix
        return TextEdit(range: selection, replacement: next,
                        selection: NSRange(location: caret + (next as NSString).length, length: 0))
    }

    // MARK: - 缩进

    /// Tab / ⇧Tab：选区跨多行、或光标所在行是列表项时，整行缩进 / 反缩进；否则不介入
    public static func indent(text: String, selection: NSRange, outdent: Bool) -> TextEdit? {
        let ns = text as NSString
        let linesRange = ns.lineRange(for: selection)
        let firstLine = contentLineRange(in: ns, at: selection.location)
        let multiLine = NSMaxRange(selection) > NSMaxRange(firstLine)
        guard multiLine || ListItemPrefix(line: ns.substring(with: firstLine)) != nil else { return nil }

        // 最后一个换行符不算入（避免把下一行也缩进）
        var blockRange = linesRange
        if blockRange.length > 0, ns.character(at: NSMaxRange(blockRange) - 1) == 0x0A {
            blockRange.length -= 1
        }
        let block = ns.substring(with: blockRange)
        var lines = block.components(separatedBy: "\n")

        var firstDelta = 0
        var totalDelta = 0
        for i in lines.indices {
            let old = lines[i] as NSString
            let new: String
            if outdent {
                new = removeOneIndent(lines[i])
            } else {
                new = old.length == 0 && lines.count > 1 ? lines[i] : indentUnit + lines[i]
            }
            let delta = (new as NSString).length - old.length
            if i == 0 { firstDelta = delta }
            totalDelta += delta
            lines[i] = new
        }
        guard totalDelta != 0 else { return nil }

        let replacement = lines.joined(separator: "\n")
        // 选区跟着文字走：起点随首行移动（不越过行首），长度吸收其余变化
        let start = max(blockRange.location, selection.location + firstDelta)
        let end = max(start, NSMaxRange(selection) + totalDelta)
        return TextEdit(range: blockRange, replacement: replacement,
                        selection: NSRange(location: start, length: end - start))
    }

    // MARK: - 工具

    private static func hasStyle(_ style: InlineStyle, run: Int) -> Bool {
        switch style {
        case .bold: return run == 2 || run == 3
        case .italic: return run == 1 || run == 3
        case .code: return run >= 1
        }
    }

    /// 以 `end` 结尾的连续 `c` 个数
    private static func run(of c: Character, in ns: NSString, endingAt end: Int) -> Int {
        let unit = c.utf16.first!
        var i = end - 1
        var n = 0
        while i >= 0, ns.character(at: i) == unit { n += 1; i -= 1 }
        return n
    }

    /// 从 `start` 开始的连续 `c` 个数
    private static func run(of c: Character, in ns: NSString, startingAt start: Int) -> Int {
        let unit = c.utf16.first!
        var i = start
        var n = 0
        while i < ns.length, ns.character(at: i) == unit { n += 1; i += 1 }
        return n
    }

    private static func looksLikeURL(_ s: String) -> Bool {
        guard !s.contains(" "), let url = URL(string: s), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "file"].contains(scheme)
    }

    /// 光标所在行（不含行尾换行）
    static func contentLineRange(in ns: NSString, at location: Int) -> NSRange {
        var start = 0, end = 0, contentsEnd = 0
        ns.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
        return NSRange(location: start, length: contentsEnd - start)
    }

    /// `location` 之前是否处在未闭合的围栏代码块里
    static func isInsideFence(_ ns: NSString, before location: Int) -> Bool {
        var inside = false
        ns.enumerateSubstrings(in: NSRange(location: 0, length: location), options: [.byLines]) { line, _, _, _ in
            let t = (line ?? "").trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") || t.hasPrefix("~~~") { inside.toggle() }
        }
        return inside
    }

    private static func removeOneIndent(_ line: String) -> String {
        if line.hasPrefix("\t") { return String(line.dropFirst()) }
        let spaces = line.prefix { $0 == " " }.count
        return String(line.dropFirst(min(spaces, indentUnit.count)))
    }
}

/// 列表项行首：缩进 + 标记（`-` `*` `+` / `1.` `1)`）+ 空格 + 可选任务框
struct ListItemPrefix {
    let indent: String
    let marker: String
    let spacing: String
    let task: String?

    /// 整个前缀的 UTF-16 长度
    var length: Int { ((indent + marker + spacing + (task ?? "")) as NSString).length }

    private static let regex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(\[[ xX]\][ \t]+)?"#)

    init?(line: String) {
        let ns = line as NSString
        guard let m = Self.regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        indent = ns.substring(with: m.range(at: 1))
        marker = ns.substring(with: m.range(at: 2))
        spacing = ns.substring(with: m.range(at: 3))
        task = m.range(at: 4).location == NSNotFound ? nil : ns.substring(with: m.range(at: 4))
        // 「- 」后面全是 - 的是分割线（如 `- - -`），不是列表
        if marker == "-" || marker == "*" {
            let rest = ns.substring(from: m.range.location + m.range.length).replacingOccurrences(of: " ", with: "")
            if !rest.isEmpty, rest.allSatisfy({ String($0) == marker }) { return nil }
        }
    }

    /// 下一项的前缀：有序号的 +1，任务项换成未勾选
    var nextPrefix: String {
        var nextMarker = marker
        if let last = marker.last, last == "." || last == ")", let n = Int(marker.dropLast()) {
            nextMarker = "\(n + 1)\(last)"
        }
        return indent + nextMarker + spacing + (task == nil ? "" : "[ ] ")
    }
}
