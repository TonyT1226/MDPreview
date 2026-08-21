import SwiftUI

/// 悬浮液态玻璃状态胶囊（极简展示文档字数与行数）
public struct FloatingStatusCapsule: View {
    public let stats: DocumentStats
    @State private var isHovered: Bool = false

    public init(stats: DocumentStats) {
        self.stats = stats
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text("\(stats.characterCount) 字")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.4))

            Text("\(stats.lineCount) 行")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassPill()
        .opacity(isHovered ? 1.0 : 0.65)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 12)
    }
}
