import Foundation

/// 两段文本之间的最小替换：去掉公共前缀和公共后缀，剩下中间一段（UTF-16 偏移）
enum TextDiff {
    struct Change: Equatable {
        let range: NSRange
        let replacement: String
    }

    static func change(from old: String, to new: String) -> Change {
        let a = old as NSString
        let b = new as NSString
        let maxPrefix = min(a.length, b.length)
        var prefix = 0
        while prefix < maxPrefix, a.character(at: prefix) == b.character(at: prefix) { prefix += 1 }
        var suffix = 0
        while suffix < maxPrefix - prefix,
              a.character(at: a.length - 1 - suffix) == b.character(at: b.length - 1 - suffix) { suffix += 1 }
        // 不在代理对中间切开
        if prefix > 0, prefix < a.length, UTF16.isTrailSurrogate(a.character(at: prefix)) { prefix -= 1 }
        if suffix > 0, a.length - suffix > prefix, UTF16.isTrailSurrogate(a.character(at: a.length - suffix)) { suffix -= 1 }
        let range = NSRange(location: prefix, length: a.length - prefix - suffix)
        let replacement = b.substring(with: NSRange(location: prefix, length: b.length - prefix - suffix))
        return Change(range: range, replacement: replacement)
    }
}
