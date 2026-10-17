import Testing
import Foundation
@testable import MDPreviewCore

@Suite("分屏布局")
@MainActor
struct SplitPaneTests {

    typealias Pane = SplitPane<Never, Never>

    @Test("左栏宽度按比例取，并夹在最小宽度之间")
    func leftWidth() {
        #expect(Pane.leftWidth(total: 1001, fraction: 0.5, minPaneWidth: 300) == 500)
        #expect(Pane.leftWidth(total: 1001, fraction: 0.1, minPaneWidth: 300) == 300)
        #expect(Pane.leftWidth(total: 1001, fraction: 0.95, minPaneWidth: 300) == 700)
    }

    @Test("放不下两个最小宽度时对半分，两栏加起来不超过可用宽度")
    func narrow() {
        for fraction in [0.0, 0.3, 0.5, 0.9, 1.0] {
            let left = Pane.leftWidth(total: 401, fraction: fraction, minPaneWidth: 300)
            #expect(left == 200)
        }
        #expect(Pane.leftWidth(total: 0, fraction: 0.5, minPaneWidth: 300) == 0)
    }

    @Test("窗口最小宽度：分屏且侧边栏开着时最宽")
    func minWindowWidth() {
        let pane = MainDocumentView.minPaneWidth, sidebar = MainDocumentView.sidebarMinWidth
        #expect(MainDocumentView.minWindowWidth(viewMode: .reading, showTOC: true) == 700)
        #expect(MainDocumentView.minWindowWidth(viewMode: .split, showTOC: false) == pane * 2 + 1)
        #expect(MainDocumentView.minWindowWidth(viewMode: .split, showTOC: true) == pane * 2 + 1 + sidebar)
    }
}
