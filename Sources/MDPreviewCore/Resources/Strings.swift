import Foundation

/// 面向用户的字符串**唯一集中点**。
///
/// 目前全部为简体中文字面量。
/// v1.3：把这里每个 `static let` / 函数体换成 `String(localized:)`（键即属性名），
/// 其余代码一行不用动 —— 这是本项目国际化的单一改造面。
public enum L {

    // MARK: - 视图模式

    public static let viewModeReading = "阅读"
    public static let viewModeEditing = "编辑"
    public static let viewModeSplit = "分屏"
    public static let switchViewModeHelp = "切换视图模式"

    // MARK: - 菜单

    public static let menuView = "视图"

    public static let readingMode = "阅读模式"
    public static let editingMode = "编辑模式"
    public static let splitMode = "分屏模式"
    public static let showOutline = "显示目录大纲"
    public static let hideOutline = "隐藏目录大纲"

    public static let printDocument = "打印…"
    public static let exportPDF = "导出为 PDF…"

    // MARK: - 大纲侧边栏

    public static let outlineTitle = "目录大纲"
    public static let outlineEmpty = "当前文档无标题层级"
    public static func outlineItemCount(_ n: Int) -> String { "\(n) 项" }

    // MARK: - 阅读区

    public static let emptyDocument = "空白文档"
    public static let untitledDocument = "未命名.md"

    // MARK: - 代码块

    public static let copy = "复制"
    public static let copied = "已复制"

    // MARK: - 图片占位

    public static let imageGenericAlt = "图片"
    public static let imageLoadFailed = "图片加载失败"
    public static let imageCannotLoad = "无法加载图片"
    public static let imageInvalidPath = "图片路径无效"
    /// 占位符正文 + 可选 alt 文本，如「图片加载失败：示意图」
    public static func imagePlaceholder(_ message: String, alt: String) -> String {
        alt.isEmpty ? message : "\(message)：\(alt)"
    }

    // MARK: - 状态胶囊

    public static func wordCount(_ n: Int) -> String { "\(n) 字" }
    public static func lineCount(_ n: Int) -> String { "\(n) 行" }

    // MARK: - 外部修改热重载

    public static let externalChangeTitle = "文件已被外部修改"
    public static let externalChangeMessage = "磁盘上的内容与当前窗口中的未保存改动冲突，要保留哪一份？"
    public static let keepMyChanges = "保留我的更改"
    public static let useDiskVersion = "使用磁盘版本"
    public static let fileDeletedOnDisk = "此文件已在磁盘上被删除或移动。"

    // MARK: - 导出

    public static let exportPDFPanelTitle = "导出为 PDF"
    public static func exportPDFDefaultName(title: String) -> String {
        let stem = (title as NSString).deletingPathExtension
        return stem.isEmpty ? "文档.pdf" : "\(stem).pdf"
    }
}
