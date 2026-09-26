import AppKit

/// 编辑器左侧行号栏（TextKit 2）。
///
/// 只读 `textLayoutManager`，**不碰** `layoutManager` —— 访问后者会让 NSTextView 退回 TextKit 1。
/// 行号按「源码行」（以换行分隔）计，折行不增加行号；光标所在行的行号加深。
final class LineNumberRulerView: NSRulerView {

    private weak var textView: NSTextView?
    /// 每一行起点的 UTF-16 偏移（升序），文本变化时重建
    private var lineStarts: [Int] = [0]
    private var font: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        rebuildLineStarts()
        updateThickness()
        setAccessibilityElement(false)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    func setFontSize(_ size: CGFloat) {
        let f = NSFont.monospacedDigitSystemFont(ofSize: max(9, (size * 0.82).rounded()), weight: .regular)
        guard f != font else { return }
        font = f
        updateThickness()
        needsDisplay = true
    }

    func textDidChange() {
        rebuildLineStarts()
        updateThickness()
        needsDisplay = true
    }

    private func rebuildLineStarts() {
        guard let string = textView?.string else { lineStarts = [0]; return }
        var starts = [0]
        let utf16 = string.utf16
        var offset = 0
        for unit in utf16 {
            offset += 1
            if unit == 0x0A { starts.append(offset) }
        }
        lineStarts = starts
    }

    private func updateThickness() {
        let digits = max(3, String(lineStarts.count).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: font]).width
        let thickness = ceil(CGFloat(digits) * digitWidth + 20)
        if ruleThickness != thickness { ruleThickness = thickness }
    }

    /// 偏移所在行（0 基），二分查找
    private func lineIndex(for offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// 不调 super：NSRulerView 默认会在右侧画一条分隔线，这条线会一直延伸到标题栏下面
    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let tlm = textView.textLayoutManager,
              let tcm = tlm.textContentManager else { return }

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let visible = textView.visibleRect
        let inset = textView.textContainerOrigin.y
        let caret = textView.selectedRange().location
        let currentLine = lineIndex(for: caret)

        let normal: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
        let current: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let rightPad: CGFloat = 8

        // 从视口顶部附近开始逐段落枚举，超出视口就停
        let topPoint = CGPoint(x: 0, y: max(0, visible.minY - inset))
        let start = tlm.textLayoutFragment(for: topPoint)?.rangeInElement.location ?? tlm.documentRange.location

        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            let y = frame.minY + inset - visible.minY
            if y > self.bounds.height { return false }

            let offset = tcm.offset(from: tcm.documentRange.location, to: fragment.rangeInElement.location)
            let line = self.lineIndex(for: offset)
            let label = "\(line + 1)" as NSString
            let attrs = line == currentLine ? current : normal
            let size = label.size(withAttributes: attrs)

            // 与段落首行基线对齐
            var baselineY = y
            if let firstLine = fragment.textLineFragments.first {
                let lineBounds = firstLine.typographicBounds
                baselineY = y + lineBounds.minY + (lineBounds.height - size.height) / 2
            }
            label.draw(at: NSPoint(x: self.bounds.width - size.width - rightPad, y: baselineY), withAttributes: attrs)
            return true
        }

        // 文末空行：以换行结尾时最后一段后面还有一行可输入，也给它编号
        if textView.string.hasSuffix("\n") {
            var last: NSTextLayoutFragment?
            tlm.enumerateTextLayoutFragments(from: tlm.documentRange.endLocation, options: [.reverse]) {
                last = $0
                return false
            }
            if let last, let extra = last.textLineFragments.last, last.textLineFragments.count > 1 || extra.characterRange.length == 0 {
                let y = last.layoutFragmentFrame.minY + extra.typographicBounds.minY + inset - visible.minY
                let line = lineStarts.count - 1
                let label = "\(line + 1)" as NSString
                let attrs = line == currentLine ? current : normal
                let size = label.size(withAttributes: attrs)
                let baselineY = y + (extra.typographicBounds.height - size.height) / 2
                label.draw(at: NSPoint(x: bounds.width - size.width - rightPad, y: baselineY), withAttributes: attrs)
            }
        }
    }
}
