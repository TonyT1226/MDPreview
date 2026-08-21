import SwiftUI

/// 遵循苹果原生 macOS HIG 与 Liquid Glass 的原生统一工具栏 (Native Unified Toolbar)
public struct NativeUnifiedToolbar: ToolbarContent {
    @ObservedObject var state: EditorState

    public init(state: EditorState) {
        self.state = state
    }

    public var body: some ToolbarContent {
        // 正中间：紧凑精巧的原生分段模式控制器
        // （左侧侧边栏开关由 NavigationSplitView 原生自动提供，无需重复添加）
        ToolbarItem(placement: .principal) {
            Picker("", selection: Binding(
                get: { state.viewMode },
                set: { newMode in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        state.viewMode = newMode
                    }
                }
            )) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .help("切换视图模式")
        }
    }
}
