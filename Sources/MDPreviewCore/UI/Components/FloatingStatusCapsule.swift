import SwiftUI

/// 悬浮液态玻璃状态胶囊：默认只显示字数，鼠标悬停时展开显示行数
public struct FloatingStatusCapsule: View {
    public let stats: DocumentStats
    @State private var isHovered = false

    public init(stats: DocumentStats) {
        self.stats = stats
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(L.wordCount(stats.wordCount))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if isHovered {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))
                Text(L.lineCount(stats.lineCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassPill()
        .opacity(isHovered ? 1.0 : 0.65)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(L.lineCount(stats.lineCount))
        .padding(.trailing, 16)
        .padding(.bottom, 12)
    }
}
