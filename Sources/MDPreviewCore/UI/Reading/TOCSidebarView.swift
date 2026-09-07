import SwiftUI

/// 目录大纲侧边栏组件（遵循 macOS Preview 质感与自然动画）
public struct TOCSidebarView: View {
    public let items: [TOCItem]
    @Binding public var targetScrollId: String?
    public var activeId: String?

    public init(items: [TOCItem], targetScrollId: Binding<String?>, activeId: String? = nil) {
        self.items = items
        self._targetScrollId = targetScrollId
        self.activeId = activeId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部大纲标题栏
            HStack {
                Label("目录大纲", systemImage: "list.bullet.indent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                
                Text("\(totalItemCount(items)) 项")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.2)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("当前文档无标题层级")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(items) { item in
                            TOCItemRow(item: item, targetScrollId: $targetScrollId, activeId: activeId)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minWidth: 180, maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func totalItemCount(_ list: [TOCItem]) -> Int {
        list.reduce(0) { $0 + 1 + totalItemCount($1.children) }
    }
}

/// 大纲单行项（支持平滑旋转折叠与流体过渡）
struct TOCItemRow: View {
    let item: TOCItem
    @Binding var targetScrollId: String?
    var activeId: String?
    @State private var isExpanded: Bool = true
    @State private var isHovered: Bool = false

    var isSelected: Bool {
        activeId == item.id || (activeId == nil && targetScrollId == item.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // 递归缩进
                if item.level > 1 {
                    Spacer()
                        .frame(width: CGFloat((item.level - 1) * 12))
                }

                // 旋转展开折叠小箭头
                if !item.children.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }

                // 标题文本按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        targetScrollId = item.id
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(.system(size: fontSizeForLevel(item.level), weight: fontWeightForLevel(item.level)))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }

            // 子层级展开动画
            if isExpanded && !item.children.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(item.children) { child in
                        TOCItemRow(item: child, targetScrollId: $targetScrollId, activeId: activeId)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.primary.opacity(0.06)
        } else {
            return Color.clear
        }
    }

    private func fontSizeForLevel(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 12.5
        case 2: return 12.0
        default: return 11.5
        }
    }

    private func fontWeightForLevel(_ level: Int) -> Font.Weight {
        switch level {
        case 1: return .medium
        case 2: return .regular
        default: return .regular
        }
    }
}

#if DEBUG
struct TOCSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        TOCSidebarView(
            items: [
                TOCItem(id: "h1", level: 1, title: "文档标题", children: [
                    TOCItem(id: "h2a", level: 2, title: "第一节", children: []),
                    TOCItem(id: "h2b", level: 2, title: "第二节", children: [
                        TOCItem(id: "h3", level: 3, title: "子章节", children: [])
                    ])
                ])
            ],
            targetScrollId: .constant(nil)
        )
        .frame(height: 400)
    }
}
#endif

