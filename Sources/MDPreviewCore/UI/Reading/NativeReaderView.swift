import SwiftUI

/// 纯原生 Markdown 阅读视图容器（跨块文本选择 + TOC 滚动联动）
public struct NativeReaderView: View {
    public let parsedDoc: ParsedDocument
    @Binding public var targetScrollId: String?
    @Binding public var activeHeadingId: String?
    public var baseURL: URL?
    public var onToggleTask: @Sendable (Int, Bool) -> Void

    public init(
        parsedDoc: ParsedDocument,
        targetScrollId: Binding<String?>,
        activeHeadingId: Binding<String?> = .constant(nil),
        baseURL: URL? = nil,
        onToggleTask: @escaping @Sendable (Int, Bool) -> Void = { _, _ in }
    ) {
        self.parsedDoc = parsedDoc
        self._targetScrollId = targetScrollId
        self._activeHeadingId = activeHeadingId
        self.baseURL = baseURL
        self.onToggleTask = onToggleTask
    }

    @State private var activeHeadingWork: Task<Void, Never>?

    private var renderContext: MarkdownRenderContext {
        MarkdownRenderContext(baseURL: baseURL, onToggleTask: onToggleTask)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    if parsedDoc.blocks.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(parsedDoc.blocks) { block in
                                MarkdownBlockDispatcher(block: block)
                            }
                        }
                    }
                }
                .textSelection(.enabled)
                .environment(\.markdownContext, renderContext)
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "reader")
            .onPreferenceChange(HeadingOffsetsKey.self) { offsets in
                updateActiveHeading(from: offsets)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text(L.emptyDocument).font(.system(size: 14)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.top, 40)
    }

    private func updateActiveHeading(from offsets: [String: CGFloat]) {
        // 视口顶部 ~80pt 处最后一个已滚过的标题即当前章节
        let threshold: CGFloat = 80
        let passed = offsets.filter { $0.value <= threshold }
        let current = passed.max(by: { $0.value < $1.value })?.key
            ?? offsets.min(by: { $0.value < $1.value })?.key
        guard current != activeHeadingId else { return }

        // onPreferenceChange 在视图更新期间触发；用带 sleep 的 Task 把写状态推到
        // 本帧渲染彻底结束之后，断开「写 activeHeadingId → 重排 → 偏好又变」的同帧回路。
        // （否则会报 "Publishing changes from within view updates" /
        //   "preference tried to update multiple times per frame"）
        activeHeadingWork?.cancel()
        activeHeadingWork = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled, current != activeHeadingId else { return }
            activeHeadingId = current
        }
    }
}
