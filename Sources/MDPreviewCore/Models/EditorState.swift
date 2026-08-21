import SwiftUI
import Combine

public enum ViewMode: String, CaseIterable, Identifiable, Sendable {
    case reading = "阅读"
    case editing = "编辑"
    case split = "分屏"

    public var id: String { rawValue }

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
    public var readingTimeMinutes: Int = 1

    public init(text: String = "") {
        self.characterCount = text.count
        self.lineCount = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count
        
        let words = text.split { $0.isWhitespace || $0.isPunctuation }
        self.wordCount = words.count
        
        // 平均按每分钟阅读 300 字估算
        self.readingTimeMinutes = max(1, Int(ceil(Double(max(words.count, text.count / 2)) / 300.0)))
    }
}

@MainActor
public final class EditorState: ObservableObject {
    @Published public var viewMode: ViewMode = .reading
    @Published public var showTOC: Bool = true
    @Published public var searchText: String = ""
    @Published public var isSearchPresented: Bool = false
    @Published public var targetScrollId: String? = nil
    @Published public var fontSizeDelta: Double = 0.0

    public init(viewMode: ViewMode = .reading, showTOC: Bool = true) {
        self.viewMode = viewMode
        self.showTOC = showTOC
    }

    public func toggleViewMode() {
        switch viewMode {
        case .reading:
            viewMode = .editing
        case .editing:
            viewMode = .reading
        case .split:
            viewMode = .reading
        }
    }
}
