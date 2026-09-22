import SwiftUI
import Combine

public enum ViewMode: String, CaseIterable, Identifiable, Sendable {
    case reading
    case editing
    case split

    public var id: String { rawValue }

    /// 面向用户的显示名（走集中的字符串表）
    public var title: String {
        switch self {
        case .reading: return L.viewModeReading
        case .editing: return L.viewModeEditing
        case .split: return L.viewModeSplit
        }
    }

    public var icon: String {
        switch self {
        case .reading: return "book.pages"
        case .editing: return "square.and.pencil"
        case .split: return "rectangle.split.2x1"
        }
    }
}

public struct DocumentStats: Sendable, Hashable {
    public var characterCount: Int = 0
    public var wordCount: Int = 0
    public var lineCount: Int = 0

    public init(text: String = "") {
        self.characterCount = text.count
        self.lineCount = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count

        // CJK 字符按「字」计；剩余（拉丁等）文本按「词」计；两者相加
        var cjkCount = 0
        var latinScalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if Self.isCJK(scalar) {
                cjkCount += 1
            } else {
                latinScalars.append(scalar)
            }
        }
        let latinWords = String(latinScalars)
            .split { $0.isWhitespace || ($0.isPunctuation && !$0.isLetter) }
            .count
        self.wordCount = cjkCount + latinWords
    }

    private static func isCJK(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x4E00...0x9FFF,   // CJK 统一表意文字
             0x3400...0x4DBF,   // 扩展 A
             0x3040...0x30FF,   // 平假名 / 片假名
             0xAC00...0xD7AF,   // 韩文音节
             0xF900...0xFAFF:   // 兼容表意文字
            return true
        default:
            return false
        }
    }
}

@MainActor
public final class EditorState: ObservableObject {
    @Published public var viewMode: ViewMode = .reading
    @Published public var showTOC: Bool = true
    @Published public var searchText: String = ""
    @Published public var isSearchPresented: Bool = false
    @Published public var targetScrollId: String? = nil
    /// 正文滚动时当前视口顶部最近的标题 id（用于 TOC 联动高亮）
    @Published public var activeHeadingId: String? = nil

    public init(viewMode: ViewMode = .reading, showTOC: Bool = true) {
        self.viewMode = viewMode
        self.showTOC = showTOC
    }

    public func toggleViewMode() {
        viewMode = (viewMode == .reading) ? .editing : .reading
    }

    public func setViewMode(_ mode: ViewMode) {
        withAnimation(.easeInOut(duration: 0.18)) { viewMode = mode }
    }

    public func toggleTOC() {
        withAnimation(.smooth(duration: 0.28)) { showTOC.toggle() }
    }
}

// MARK: - FocusedValue 桥接（供 App 场景的菜单命令触达当前窗口的状态）

public struct EditorStateFocusedValueKey: FocusedValueKey {
    public typealias Value = EditorState
}

public struct PrintableDocumentFocusedValueKey: FocusedValueKey {
    public typealias Value = PrintableDocument
}

public extension FocusedValues {
    var editorState: EditorState? {
        get { self[EditorStateFocusedValueKey.self] }
        set { self[EditorStateFocusedValueKey.self] = newValue }
    }

    /// 当前聚焦窗口的文档快照，供「打印 / 导出 PDF」菜单命令使用
    var printableDocument: PrintableDocument? {
        get { self[PrintableDocumentFocusedValueKey.self] }
        set { self[PrintableDocumentFocusedValueKey.self] = newValue }
    }
}
