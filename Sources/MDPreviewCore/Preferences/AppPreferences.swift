import SwiftUI
import AppKit

/// 偏好设置的键与默认值（`@AppStorage` 与非 SwiftUI 代码共用这一份定义）
public enum PrefKey {
    public static let fontSize = "reader.fontSize"
    public static let lineHeight = "reader.lineHeight"
    public static let contentWidth = "reader.contentWidth"
    public static let fontFamily = "reader.fontFamily"
    public static let theme = "app.theme"
    public static let editorHighlighting = "editor.sourceHighlighting"
}

public enum ReaderFontFamily: String, CaseIterable, Identifiable, Sendable {
    case system
    case serif
    case monospaced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return L.fontSystem
        case .serif: return L.fontSerif
        case .monospaced: return L.fontMonospaced
        }
    }
}

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return L.themeSystem
        case .light: return L.themeLight
        case .dark: return L.themeDark
        }
    }

    /// nil 表示跟随系统
    public var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// 阅读区排版参数（渲染器的输入；与 UserDefaults 解耦，便于测试与打印时使用固定值）
public struct ReaderStyle: Sendable, Equatable {
    public var fontSize: CGFloat
    public var lineHeight: CGFloat
    public var contentWidth: CGFloat
    public var fontFamily: ReaderFontFamily

    public static let fontSizeRange: ClosedRange<CGFloat> = 10...28
    public static let lineHeightRange: ClosedRange<CGFloat> = 1.0...2.2
    public static let contentWidthRange: ClosedRange<CGFloat> = 520...1400

    public static let `default` = ReaderStyle(fontSize: 15, lineHeight: 1.45, contentWidth: 820, fontFamily: .system)

    public init(fontSize: CGFloat, lineHeight: CGFloat, contentWidth: CGFloat, fontFamily: ReaderFontFamily) {
        self.fontSize = fontSize.clamped(to: Self.fontSizeRange)
        self.lineHeight = lineHeight.clamped(to: Self.lineHeightRange)
        self.contentWidth = contentWidth.clamped(to: Self.contentWidthRange)
        self.fontFamily = fontFamily
    }

    /// 从 UserDefaults 读当前偏好
    public static func current(_ defaults: UserDefaults = .standard) -> ReaderStyle {
        let d = ReaderStyle.default
        func cg(_ key: String, _ fallback: CGFloat) -> CGFloat {
            defaults.object(forKey: key) == nil ? fallback : CGFloat(defaults.double(forKey: key))
        }
        return ReaderStyle(
            fontSize: cg(PrefKey.fontSize, d.fontSize),
            lineHeight: cg(PrefKey.lineHeight, d.lineHeight),
            contentWidth: cg(PrefKey.contentWidth, d.contentWidth),
            fontFamily: defaults.string(forKey: PrefKey.fontFamily).flatMap(ReaderFontFamily.init(rawValue:)) ?? d.fontFamily
        )
    }
}

/// 全局字号缩放（⌘+ / ⌘- / ⌘0），改的是偏好里的字号
@MainActor
public enum FontZoom {
    public static func increase() { adjust(by: 1) }
    public static func decrease() { adjust(by: -1) }
    public static func reset() {
        UserDefaults.standard.set(Double(ReaderStyle.default.fontSize), forKey: PrefKey.fontSize)
    }

    private static func adjust(by delta: CGFloat) {
        let current = ReaderStyle.current().fontSize
        let next = (current + delta).clamped(to: ReaderStyle.fontSizeRange)
        UserDefaults.standard.set(Double(next), forKey: PrefKey.fontSize)
    }
}

/// 把主题偏好应用到整个 App（`NSApp.appearance`），并跟随偏好变化
@MainActor
public final class ThemeController {
    public static let shared = ThemeController()
    private var observer: NSObjectProtocol?

    public func start() {
        apply()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ThemeController.shared.apply() }
        }
    }

    private func apply() {
        let theme = UserDefaults.standard.string(forKey: PrefKey.theme).flatMap(AppTheme.init(rawValue:)) ?? .system
        let target = theme.appearance
        if NSApp.appearance?.name != target?.name {
            NSApp.appearance = target
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
