import AppKit

/// 纯原生轻量代码语法着色引擎
public struct NativeSyntaxHighlighter: Sendable {
    
    public static func highlight(code: String, language: String?) -> AttributedString {
        // 只着色，不定字体：等宽字体与字号由 ReaderRenderer 统一设置
        let lang = (language ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        if lang.isEmpty {
            return AttributedString(code)
        }

        let keywords: Set<String>
        let types: Set<String>
        let commentPrefixes: [String]

        switch lang {
        case "swift":
            keywords = ["import", "let", "var", "func", "class", "struct", "enum", "protocol", "extension", "public", "private", "fileprivate", "open", "internal", "static", "final", "override", "mutating", "nonmutating", "init", "deinit", "return", "if", "else", "guard", "switch", "case", "default", "for", "in", "while", "repeat", "break", "continue", "fallthrough", "try", "catch", "throw", "throws", "rethrows", "async", "await", "actor", "some", "any", "self", "Self", "nil", "true", "false", "where", "as", "is"]
            types = ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional", "View", "Some", "Task", "MainActor", "Sendable", "AttributedString", "Color", "UUID", "Date", "Data", "Error"]
            commentPrefixes = ["//"]
        case "python", "py":
            keywords = ["def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "while", "break", "continue", "try", "except", "finally", "raise", "with", "yield", "lambda", "global", "nonlocal", "pass", "None", "True", "False", "and", "or", "not", "is", "in", "async", "await"]
            types = ["int", "float", "str", "bool", "list", "dict", "set", "tuple", "object", "type"]
            commentPrefixes = ["#"]
        case "js", "javascript", "ts", "typescript":
            keywords = ["const", "let", "var", "function", "class", "extends", "return", "if", "else", "switch", "case", "default", "for", "while", "do", "break", "continue", "try", "catch", "finally", "throw", "import", "export", "from", "default", "async", "await", "new", "this", "typeof", "instanceof", "null", "undefined", "true", "false", "interface", "type", "enum"]
            types = ["string", "number", "boolean", "any", "void", "never", "unknown", "Promise", "Array", "Object"]
            commentPrefixes = ["//"]
        case "json":
            keywords = ["true", "false", "null"]
            types = []
            commentPrefixes = []
        case "sh", "bash", "zsh", "shell":
            keywords = ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in", "function", "return", "exit", "echo", "export", "local", "source", "alias"]
            types = []
            commentPrefixes = ["#"]
        case "rust", "rs":
            keywords = ["fn", "let", "mut", "struct", "enum", "impl", "trait", "pub", "use", "mod", "crate", "super", "self", "Self", "match", "if", "else", "for", "while", "loop", "return", "break", "continue", "where", "async", "await", "unsafe", "dyn", "ref", "true", "false"]
            types = ["i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128", "f32", "f64", "bool", "char", "str", "String", "Vec", "Option", "Result", "Box", "Rc", "Arc"]
            commentPrefixes = ["//"]
        case "go", "golang":
            keywords = ["func", "var", "const", "type", "struct", "interface", "package", "import", "return", "if", "else", "switch", "case", "default", "for", "range", "go", "chan", "select", "defer", "nil", "true", "false"]
            types = ["string", "int", "int64", "float64", "bool", "byte", "rune", "error", "any"]
            commentPrefixes = ["//"]
        default:
            keywords = ["func", "function", "def", "class", "var", "let", "const", "return", "if", "else", "for", "while", "true", "false", "null", "nil"]
            types = ["String", "Int", "Bool", "Array", "Object"]
            commentPrefixes = ["//", "#"]
        }

        // 分行处理语法高亮
        let lines = code.components(separatedBy: .newlines)
        var result = AttributedString()
        
        for (i, line) in lines.enumerated() {
            result.append(highlightLine(
                line: line,
                keywords: keywords,
                types: types,
                commentPrefixes: commentPrefixes
            ))
            if i < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    private static func highlightLine(
        line: String,
        keywords: Set<String>,
        types: Set<String>,
        commentPrefixes: [String]
    ) -> AttributedString {
        var attributed = AttributedString(line)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // 1. 注释整行检查
        for prefix in commentPrefixes {
            if trimmed.hasPrefix(prefix) {
                attributed.appKit.foregroundColor = .systemGreen
                return attributed
            }
        }

        // 2. 正则分词高亮
        let pattern = #"(\".*?\"|'.*?'|\b\d+(\.\d+)?\b|[a-zA-Z_]\w*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributed
        }

        let nsString = line as NSString
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard let swiftRange = Range(match.range, in: line),
                  let attrRange = Range(swiftRange, in: attributed) else { continue }
            
            let token = String(line[swiftRange])
            
            if token.hasPrefix("\"") || token.hasPrefix("'") {
                // 字符串
                attributed[attrRange].appKit.foregroundColor = .systemRed
            } else if Double(token) != nil {
                // 数字
                attributed[attrRange].appKit.foregroundColor = .systemBlue
            } else if keywords.contains(token) {
                // 关键字
                attributed[attrRange].appKit.foregroundColor = .systemPurple
                attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
            } else if types.contains(token) {
                // 类型
                attributed[attrRange].appKit.foregroundColor = .systemTeal
            }
        }

        return attributed
    }
}
