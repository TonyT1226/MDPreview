import SwiftUI

/// 悬浮液态玻璃状态胶囊：默认只显示字数，鼠标悬停时向左展开，显示行数。
///
/// 行数一直在布局里，只是宽度收成 0 并被裁掉；展开时胶囊变宽，行数在原地淡入。
/// 这样文字不会从胶囊外面滑进来，也不会超出胶囊的范围。
public struct FloatingStatusCapsule: View {
    public let stats: DocumentStats
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(stats: DocumentStats) {
        self.stats = stats
    }

    public var body: some View {
        HStack(spacing: 0) {
            Text(L.wordCount(stats.wordCount))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize()

            HStack(spacing: 6) {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))
                Text(L.lineCount(stats.lineCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 6)
            .fixedSize()
            .frame(width: isHovered ? nil : 0, alignment: .leading)
            .opacity(isHovered ? 1 : 0)
            .blur(radius: isHovered || reduceMotion ? 0 : 3)
            .clipped()
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .clipShape(Capsule())
        .glassPill()
        .opacity(isHovered ? 1.0 : 0.65)
        .onHover { hovering in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.12) : .spring(response: 0.36, dampingFraction: 0.82)) {
                isHovered = hovering
            }
        }
        .help(L.lineCount(stats.lineCount))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.statusAccessibilityLabel(words: stats.wordCount, lines: stats.lineCount))
        .padding(.trailing, 16)
        .padding(.bottom, 12)
    }
}
