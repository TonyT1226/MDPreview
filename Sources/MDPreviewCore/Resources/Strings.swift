import Foundation

/// 面向用户的字符串**唯一集中点**。
///
/// 键即属性名，英文写在 `defaultValue`，其他语言在 `Localizable.xcstrings`（String Catalog）里。
/// 新增字符串：在这里加一个属性，再到 String Catalog 里补中文。
public enum L {


    // MARK: - 视图模式

    public static let viewModeReading = String(localized: "viewModeReading", defaultValue: "Reading", bundle: .module, comment: "Toolbar segment: reading mode")
    public static let viewModeEditing = String(localized: "viewModeEditing", defaultValue: "Editing", bundle: .module, comment: "Toolbar segment: editing mode")
    public static let viewModeSplit = String(localized: "viewModeSplit", defaultValue: "Split", bundle: .module, comment: "Toolbar segment: editor and reader side by side")
    public static let switchViewModeHelp = String(localized: "switchViewModeHelp", defaultValue: "Switch view mode", bundle: .module, comment: "Tooltip of the view-mode picker")

    // MARK: - 菜单

    public static let readingMode = String(localized: "readingMode", defaultValue: "Reading Mode", bundle: .module, comment: "View menu item")
    public static let editingMode = String(localized: "editingMode", defaultValue: "Editing Mode", bundle: .module, comment: "View menu item")
    public static let splitMode = String(localized: "splitMode", defaultValue: "Split Mode", bundle: .module, comment: "View menu item")
    public static let showOutline = String(localized: "showOutline", defaultValue: "Show Outline", bundle: .module, comment: "View menu item")
    public static let hideOutline = String(localized: "hideOutline", defaultValue: "Hide Outline", bundle: .module, comment: "View menu item")
    public static let zoomIn = String(localized: "zoomIn", defaultValue: "Zoom In", bundle: .module, comment: "View menu item: larger text")
    public static let zoomOut = String(localized: "zoomOut", defaultValue: "Zoom Out", bundle: .module, comment: "View menu item: smaller text")
    public static let actualSize = String(localized: "actualSize", defaultValue: "Actual Size", bundle: .module, comment: "View menu item: default text size")
    public static let menuFormat = String(localized: "menuFormat", defaultValue: "Format", bundle: .module, comment: "Menu title")
    public static let formatBold = String(localized: "formatBold", defaultValue: "Bold", bundle: .module, comment: "Format menu item")
    public static let formatItalic = String(localized: "formatItalic", defaultValue: "Italic", bundle: .module, comment: "Format menu item")
    public static let formatInlineCode = String(localized: "formatInlineCode", defaultValue: "Inline Code", bundle: .module, comment: "Format menu item")
    public static let formatLink = String(localized: "formatLink", defaultValue: "Link", bundle: .module, comment: "Format menu item")
    public static let printDocument = String(localized: "printDocument", defaultValue: "Print…", bundle: .module, comment: "File menu item")
    public static let exportPDF = String(localized: "exportPDF", defaultValue: "Export as PDF…", bundle: .module, comment: "File menu item")

    // MARK: - 大纲侧边栏

    public static let expandSection = String(localized: "expandSection", defaultValue: "Expand", bundle: .module, comment: "VoiceOver: expand an outline item")
    public static let collapseSection = String(localized: "collapseSection", defaultValue: "Collapse", bundle: .module, comment: "VoiceOver: collapse an outline item")
    public static let outlineTitle = String(localized: "outlineTitle", defaultValue: "Outline", bundle: .module, comment: "Sidebar header")
    public static let outlineEmpty = String(localized: "outlineEmpty", defaultValue: "No headings in this document", bundle: .module, comment: "Sidebar empty state")

    // MARK: - 阅读区 / 编辑区

    public static let emptyDocument = String(localized: "emptyDocument", defaultValue: "Empty document", bundle: .module, comment: "Reader empty state")
    public static let untitledDocument = String(localized: "untitledDocument", defaultValue: "Untitled.md", bundle: .module, comment: "Window title for a new document")
    public static let readerAccessibilityLabel = String(localized: "readerAccessibilityLabel", defaultValue: "Document content", bundle: .module, comment: "VoiceOver label of the reading view")
    public static let editorAccessibilityLabel = String(localized: "editorAccessibilityLabel", defaultValue: "Markdown source", bundle: .module, comment: "VoiceOver label of the editor")
    public static let taskDone = String(localized: "taskDone", defaultValue: "Done", bundle: .module, comment: "Task checkbox state (VoiceOver / tooltip)")
    public static let taskTodo = String(localized: "taskTodo", defaultValue: "To do", bundle: .module, comment: "Task checkbox state (VoiceOver / tooltip)")

    // MARK: - 图片占位

    public static let imageGenericAlt = String(localized: "imageGenericAlt", defaultValue: "Image", bundle: .module, comment: "Fallback alt text")
    public static let imageLoadFailed = String(localized: "imageLoadFailed", defaultValue: "Image failed to load", bundle: .module, comment: "Image placeholder")
    public static let imageLoading = String(localized: "imageLoading", defaultValue: "Loading image", bundle: .module, comment: "Image placeholder")
    public static let imageCannotLoad = String(localized: "imageCannotLoad", defaultValue: "Cannot load image", bundle: .module, comment: "Image placeholder")
    public static let imageInvalidPath = String(localized: "imageInvalidPath", defaultValue: "Invalid image path", bundle: .module, comment: "Image placeholder")

    // MARK: - 外部修改热重载

    public static let externalChangeTitle = String(localized: "externalChangeTitle", defaultValue: "The file was changed by another app", bundle: .module, comment: "Conflict dialog title")
    public static let externalChangeMessage = String(localized: "externalChangeMessage", defaultValue: "The file on disk conflicts with unsaved changes in this window. Which version do you want to keep?", bundle: .module, comment: "Conflict dialog message")
    public static let keepMyChanges = String(localized: "keepMyChanges", defaultValue: "Keep My Changes", bundle: .module, comment: "Conflict dialog button")
    public static let useDiskVersion = String(localized: "useDiskVersion", defaultValue: "Use Version on Disk", bundle: .module, comment: "Conflict dialog button")
    public static let fileDeletedOnDisk = String(localized: "fileDeletedOnDisk", defaultValue: "This file was deleted or moved on disk.", bundle: .module, comment: "Banner")

    // MARK: - 导出

    public static let exportPDFPanelTitle = String(localized: "exportPDFPanelTitle", defaultValue: "Export as PDF", bundle: .module, comment: "Save panel title")

    // MARK: - 偏好设置

    public static let fontSystem = String(localized: "fontSystem", defaultValue: "System", bundle: .module, comment: "Font choice")
    public static let fontSerif = String(localized: "fontSerif", defaultValue: "Serif", bundle: .module, comment: "Font choice")
    public static let fontMonospaced = String(localized: "fontMonospaced", defaultValue: "Monospaced", bundle: .module, comment: "Font choice")
    public static let themeSystem = String(localized: "themeSystem", defaultValue: "System", bundle: .module, comment: "Theme choice")
    public static let themeLight = String(localized: "themeLight", defaultValue: "Light", bundle: .module, comment: "Theme choice")
    public static let themeDark = String(localized: "themeDark", defaultValue: "Dark", bundle: .module, comment: "Theme choice")
    public static let prefsReading = String(localized: "prefsReading", defaultValue: "Reading", bundle: .module, comment: "Settings section")
    public static let prefsFont = String(localized: "prefsFont", defaultValue: "Font", bundle: .module, comment: "Settings row")
    public static let prefsFontSize = String(localized: "prefsFontSize", defaultValue: "Font Size", bundle: .module, comment: "Settings row")
    public static let prefsLineHeight = String(localized: "prefsLineHeight", defaultValue: "Line Spacing", bundle: .module, comment: "Settings row")
    public static let prefsContentWidth = String(localized: "prefsContentWidth", defaultValue: "Content Width", bundle: .module, comment: "Settings row")
    public static let prefsAppearance = String(localized: "prefsAppearance", defaultValue: "Appearance", bundle: .module, comment: "Settings section")
    public static let prefsTheme = String(localized: "prefsTheme", defaultValue: "Theme", bundle: .module, comment: "Settings row")
    public static let prefsEditor = String(localized: "prefsEditor", defaultValue: "Editor", bundle: .module, comment: "Settings section")
    public static let prefsLineNumbers = String(localized: "prefsLineNumbers", defaultValue: "Show line numbers", bundle: .module, comment: "Settings toggle")
    public static let prefsSourceHighlighting = String(localized: "prefsSourceHighlighting", defaultValue: "Markdown syntax coloring", bundle: .module, comment: "Settings toggle")
    public static let prefsSourceHighlightingHint = String(localized: "prefsSourceHighlightingHint", defaultValue: "Colors headings, emphasis, code, links and other syntax in the editor.", bundle: .module, comment: "Settings hint")
    public static let prefsRestoreDefaults = String(localized: "prefsRestoreDefaults", defaultValue: "Restore Defaults", bundle: .module, comment: "Settings button")

    // MARK: - 带参数

    public static func outlineItemCount(_ n: Int) -> String {
        String(localized: "outlineItemCount", defaultValue: "\(n) items", bundle: .module, comment: "Sidebar header: number of headings")
    }
    public static func wordCount(_ n: Int) -> String {
        String(localized: "wordCount", defaultValue: "\(n) words", bundle: .module, comment: "Status pill: words (CJK characters count one each)")
    }
    public static func lineCount(_ n: Int) -> String {
        String(localized: "lineCount", defaultValue: "\(n) lines", bundle: .module, comment: "Status pill: lines")
    }
    public static func pointValue(_ n: Int) -> String {
        String(localized: "pointValue", defaultValue: "\(n) pt", bundle: .module, comment: "Settings value in points")
    }
    public static func imagePlaceholderWithAlt(_ message: String, alt: String) -> String {
        String(localized: "imagePlaceholderWithAlt", defaultValue: "\(message): \(alt)", bundle: .module, comment: "Image placeholder message followed by alt text")
    }
    public static func headingAccessibilityLabel(_ level: Int, title: String) -> String {
        String(localized: "headingAccessibilityLabel", defaultValue: "Heading level \(level), \(title)", bundle: .module, comment: "VoiceOver label of an outline item")
    }
    public static func statusAccessibilityLabel(words: Int, lines: Int) -> String {
        String(localized: "statusAccessibilityLabel", defaultValue: "\(words) words, \(lines) lines", bundle: .module, comment: "VoiceOver label of the word-count pill")
    }
    static let exportPDFDocumentStem = String(localized: "exportPDFDocumentStem", defaultValue: "Document", bundle: .module, comment: "Default PDF file name when the document has no title")

    /// 占位符正文 + 可选 alt 文本，如「图片加载失败：示意图」
    public static func imagePlaceholder(_ message: String, alt: String) -> String {
        alt.isEmpty ? message : imagePlaceholderWithAlt(message, alt: alt)
    }

    public static func exportPDFDefaultName(title: String) -> String {
        let stem = (title as NSString).deletingPathExtension
        return (stem.isEmpty ? exportPDFDocumentStem : stem) + ".pdf"
    }
}
