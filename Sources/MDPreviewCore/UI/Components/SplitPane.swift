import SwiftUI
import AppKit

/// 左右两栏，中间一条可拖动的分隔线（分屏模式：编辑 | 阅读）。
///
/// 不用 `HSplitView`：窗口变窄时它不收缩两栏，内容会溢出、压到侧边栏上；
/// 分隔线还会伸进工具栏区域，和悬浮的工具栏按钮叠在一起。
/// 这里两栏宽度始终按可用宽度算，分隔线只画在安全区域里。
struct SplitPane<Left: View, Right: View>: View {
    /// 左栏占可用宽度的比例
    @Binding var fraction: CGFloat
    /// 每栏的最小宽度；可用宽度不够放两个最小宽度时对半分
    var minPaneWidth: CGFloat = 240
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    private static var space: String { "SplitPane" }
    private static var handleWidth: CGFloat { 9 }

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let leftWidth = Self.leftWidth(total: total, fraction: fraction, minPaneWidth: minPaneWidth)
            HStack(spacing: 0) {
                left.frame(width: leftWidth)
                divider(total: total)
                right.frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: Self.space)
        }
    }

    /// 左栏宽度：按比例取，再夹在两栏最小宽度之间
    static func leftWidth(total: CGFloat, fraction: CGFloat, minPaneWidth: CGFloat) -> CGFloat {
        let usable = max(0, total - 1)
        let minWidth = min(minPaneWidth, usable / 2)
        return min(max(usable * fraction, minWidth), usable - minWidth).rounded()
    }

    private func divider(total: CGFloat) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .overlay {
                // 比线宽的透明拖动区
                Color.clear
                    .frame(width: Self.handleWidth)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                            .onChanged { value in
                                guard total > 1 else { return }
                                let width = Self.leftWidth(total: total, fraction: value.location.x / total,
                                                           minPaneWidth: minPaneWidth)
                                fraction = width / (total - 1)
                            }
                    )
                    .onTapGesture(count: 2) { fraction = 0.5 }
            }
            .accessibilityHidden(true)
    }
}
