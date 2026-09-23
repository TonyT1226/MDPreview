import Testing
import Foundation
@testable import MDPreviewCore

@Suite("本地化")
struct LocalizationTests {

    private func lproj(_ lang: String) throws -> Bundle {
        let path = try #require(Bundle.module.path(forResource: lang, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test("String Catalog 里每个键都有 en 与 zh-Hans")
    func catalogComplete() throws {
        let catalogPath = #filePath.replacingOccurrences(
            of: "Tests/MDPreviewCoreTests/LocalizationTests.swift",
            with: "Sources/MDPreviewCore/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: URL(fileURLWithPath: catalogPath))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: [String: Any]])
        #expect(strings.count > 40)
        for (key, entry) in strings {
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            #expect(locs["en"] != nil, "缺少 en：\(key)")
            #expect(locs["zh-Hans"] != nil, "缺少 zh-Hans：\(key)")
        }

        // Strings.swift 里用到的键都在 catalog 里
        let swiftPath = catalogPath.replacingOccurrences(of: "Localizable.xcstrings", with: "Strings.swift")
        let source = try String(contentsOfFile: swiftPath, encoding: .utf8)
        let keys = source.matches(of: /String\(localized: "(\w+)"/).map { String($0.1) }
        #expect(keys.count > 40)
        for key in keys {
            #expect(strings[key] != nil, "catalog 缺少键：\(key)")
        }
    }

    @Test("中文翻译与英文复数都能取到")
    func lookups() throws {
        let zh = try lproj("zh-Hans")
        let en = try lproj("en")

        #expect(zh.localizedString(forKey: "readingMode", value: nil, table: nil) == "阅读模式")
        #expect(en.localizedString(forKey: "readingMode", value: nil, table: nil) == "Reading Mode")

        let zhFormat = zh.localizedString(forKey: "outlineItemCount", value: nil, table: nil)
        #expect(String.localizedStringWithFormat(zhFormat, 3) == "3 项")

        let enFormat = en.localizedString(forKey: "outlineItemCount", value: nil, table: nil)
        #expect(String.localizedStringWithFormat(enFormat, 1) == "1 item")
        #expect(String.localizedStringWithFormat(enFormat, 5) == "5 items")

        let zhAlt = zh.localizedString(forKey: "imagePlaceholderWithAlt", value: nil, table: nil)
        #expect(String(format: zhAlt, "图片加载失败", "示意图") == "图片加载失败：示意图")
    }

    @Test("L 的带参数函数能正常格式化")
    func formattedHelpers() {
        #expect(L.wordCount(12).contains("12"))
        #expect(L.imagePlaceholder("X", alt: "") == "X")
        #expect(L.imagePlaceholder("X", alt: "Y").contains("Y"))
        #expect(L.exportPDFDefaultName(title: "").hasSuffix(".pdf"))
    }
}
