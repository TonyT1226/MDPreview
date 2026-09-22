import AppKit

/// Markdown **源码**（编辑态）的轻量语法着色。
///
/// 不复用 swift-markdown 的整篇 AST —— 编辑时每次按键都要跑，成本要低。
/// 逐行 + 少量正则识别常见结构，产出 `[Token]`（`NSRange` + 类别）。
/// 跨行围栏代码块用行级状态机跟踪。
public struct MarkdownSourceHighlighter: Sendable {

    public enum Kind: Sendable {
        case heading          // # ...
        case emphasis         // *x* _x_
        case strong           // **x** __x__
        case strikethrough    // ~~x~~
        case inlineCode       // `x`
        case codeFence        // ``` 行与围栏区间
        case listMarker       // - * + 1.
        case blockquote       // >
        case link             // [text](url)
        case thematicBreak    // --- *** ___
    }

    public struct Token: Sendable, Equatable {
        public let range: NSRange
        public let kind: Kind
        public init(range: NSRange, kind: Kind) {
            self.range = range
            self.kind = kind
        }
    }

    // 行内正则（一次编译，线程安全复用）
    private static let strongRegex = try! NSRegularExpression(pattern: #"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let emphasisRegex = try! NSRegularExpression(pattern: #"(?<![\*_])([\*_])(?=\S)(.+?)(?<=\S)\1(?![\*_])"#)
    private static let strikeRegex = try! NSRegularExpression(pattern: #"~~(?=\S)(.+?)(?<=\S)~~"#)
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`[^`\n]+`"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[[^\]\n]*\]\([^)\n]*\)"#)

    /// 扫描整段源码，返回所有 token（未排序需求：调用方按顺序施加即可）
    public static func tokens(in text: String) -> [Token] {
        let ns = text as NSString
        var tokens: [Token] = []
        var inFence = false
        var searchLocation = 0

        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                               options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            // lineRange 不含行尾换行
            let line = ns.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            searchLocation = lineRange.location + lineRange.length

            // 围栏
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                tokens.append(Token(range: lineRange, kind: .codeFence))
                inFence.toggle()
                return
            }
            if inFence {
                tokens.append(Token(range: lineRange, kind: .codeFence))
                return
            }

            // 整行结构
            if isThematicBreak(trimmed) {
                tokens.append(Token(range: lineRange, kind: .thematicBreak))
                return
            }
            if let hashRange = headingPrefixRange(line: line, lineRange: lineRange) {
                tokens.append(Token(range: lineRange, kind: .heading))
                _ = hashRange
                return
            }
            if let q = blockquotePrefixRange(line: line, lineRange: lineRange) {
                tokens.append(Token(range: q, kind: .blockquote))
            }
            if let m = listMarkerRange(line: line, lineRange: lineRange) {
                tokens.append(Token(range: m, kind: .listMarker))
            }

            // 行内
            appendInline(strongRegex, in: line, base: lineRange.location, kind: .strong, into: &tokens)
            appendInline(emphasisRegex, in: line, base: lineRange.location, kind: .emphasis, into: &tokens)
            appendInline(strikeRegex, in: line, base: lineRange.location, kind: .strikethrough, into: &tokens)
            appendInline(inlineCodeRegex, in: line, base: lineRange.location, kind: .inlineCode, into: &tokens)
            appendInline(linkRegex, in: line, base: lineRange.location, kind: .link, into: &tokens)
        }
        _ = searchLocation
        return tokens
    }

    // MARK: - 行结构识别

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        return stripped.allSatisfy { $0 == "-" } || stripped.allSatisfy { $0 == "*" } || stripped.allSatisfy { $0 == "_" }
    }

    private static func headingPrefixRange(line: String, lineRange: NSRange) -> NSRange? {
        let ns = line as NSString
        var i = 0
        while i < ns.length, ns.character(at: i) == UInt16(UnicodeScalar(" ").value) { i += 1 }
        guard i <= 3 else { return nil }
        var hashes = 0
        while i + hashes < ns.length, ns.character(at: i + hashes) == UInt16(UnicodeScalar("#").value) { hashes += 1 }
        guard (1...6).contains(hashes) else { return nil }
        let after = i + hashes
        guard after == ns.length || ns.character(at: after) == UInt16(UnicodeScalar(" ").value) else { return nil }
        return NSRange(location: lineRange.location, length: after)
    }

    private static func blockquotePrefixRange(line: String, lineRange: NSRange) -> NSRange? {
        let ns = line as NSString
        var i = 0
        while i < ns.length, ns.character(at: i) == UInt16(UnicodeScalar(" ").value) { i += 1 }
        guard i < ns.length, ns.character(at: i) == UInt16(UnicodeScalar(">").value) else { return nil }
        return NSRange(location: lineRange.location, length: i + 1)
    }

    private static func listMarkerRange(line: String, lineRange: NSRange) -> NSRange? {
        let ns = line as NSString
        var i = 0
        while i < ns.length, ns.character(at: i) == UInt16(UnicodeScalar(" ").value) { i += 1 }
        guard i < ns.length else { return nil }
        let c = Character(UnicodeScalar(ns.character(at: i))!)
        // 无序
        if c == "-" || c == "*" || c == "+" {
            if i + 1 < ns.length, ns.character(at: i + 1) == UInt16(UnicodeScalar(" ").value) {
                return NSRange(location: lineRange.location + i, length: 1)
            }
            return nil
        }
        // 有序 1. / 1)
        if c.isNumber {
            var j = i
            while j < ns.length, Character(UnicodeScalar(ns.character(at: j))!).isNumber { j += 1 }
            guard j < ns.length else { return nil }
            let delim = Character(UnicodeScalar(ns.character(at: j))!)
            guard delim == "." || delim == ")" else { return nil }
            guard j + 1 < ns.length, ns.character(at: j + 1) == UInt16(UnicodeScalar(" ").value) else { return nil }
            return NSRange(location: lineRange.location + i, length: j - i + 1)
        }
        return nil
    }

    private static func appendInline(_ regex: NSRegularExpression,
                                     in line: String,
                                     base: Int,
                                     kind: Kind,
                                     into tokens: inout [Token]) {
        let ns = line as NSString
        regex.enumerateMatches(in: line, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            tokens.append(Token(range: NSRange(location: base + match.range.location, length: match.range.length), kind: kind))
        }
    }
}
