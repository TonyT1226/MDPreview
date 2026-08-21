import SwiftUI

/// 纯原生 Markdown 阅读视图容器 (支持跨行跨段落连续文本选择)
public struct NativeReaderView: View {
    public let parsedDoc: ParsedDocument
    @Binding public var targetScrollId: String?

    public init(parsedDoc: ParsedDocument, targetScrollId: Binding<String?>) {
        self.parsedDoc = parsedDoc
        self._targetScrollId = targetScrollId
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    if parsedDoc.blocks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("空白文档")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.top, 40)
                    } else {
                        ForEach(parsedDoc.blocks) { block in
                            MarkdownBlockDispatcher(block: block)
                        }
                    }
                }
                .textSelection(.enabled) // 在父容器启用统一文本选择，支持鼠标多行、多段落连贯框选
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: targetScrollId) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

#if DEBUG
struct NativeReaderView_Previews: PreviewProvider {
    static var previews: some View {
        NativeReaderView(
            parsedDoc: MarkdownASTParser.parse(markdown: "# 标题\n\n这是段落。\n\n## 子标题\n\n- 列表项 1\n- 列表项 2"),
            targetScrollId: .constant(nil)
        )
        .frame(width: 600, height: 400)
    }
}
#endif
