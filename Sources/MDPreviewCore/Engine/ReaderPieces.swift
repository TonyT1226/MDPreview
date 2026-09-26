import AppKit

/// 阅读区增量更新：记住每个顶层块渲染出的片段。新的块列表到来时，
/// 前后两端渲染结果不变的块原样保留，只重渲染中间改动的块，并只替换 text storage 里对应的一段。
///
/// storage 的内容 = 各片段依次拼接，再去掉最后一个段落结束符（与 `ReaderRenderer.render` 一致）。
@MainActor
final class ReaderPieces {
    private(set) var blocks: [MarkdownBlock] = []
    private var pieces: [RenderedPiece] = []
    /// 每个片段在「未去掉末尾换行」的全文中的起点；多一项放全文长度
    private var starts: [Int] = [0]
    private(set) var headings: [(id: String, location: Int)] = []

    struct Update: Equatable {
        /// 本次重渲染的块数
        var renderedBlocks: Int
        /// storage 中被替换的范围（替换前的坐标）
        var replacedRange: NSRange
    }

    /// 把 storage 更新到 `newBlocks`。`force` 时全部重渲染（排版参数、基准目录变了，或远程图片到了）
    @discardableResult
    func update(to newBlocks: [MarkdownBlock], renderer: ReaderRenderer,
                storage: NSTextStorage, force: Bool = false) -> Update {
        let old = blocks
        let shared = min(old.count, newBlocks.count)

        var prefix = 0
        if !force {
            while prefix < shared, old[prefix].rendersSame(as: newBlocks[prefix]) { prefix += 1 }
        }
        var suffix = 0
        if !force {
            while suffix < shared - prefix {
                let o = old.count - 1 - suffix, n = newBlocks.count - 1 - suffix
                // 第一块的标题不留上边距，所以换了位置的第一块不能复用
                guard (o == 0) == (n == 0), old[o].rendersSame(as: newBlocks[n]) else { break }
                suffix += 1
            }
        }

        let middle = (prefix..<(newBlocks.count - suffix)).map {
            renderer.renderPiece(newBlocks[$0], isFirst: $0 == 0)
        }

        // 在「带末尾换行」的全文上：[start, end) 换成 middle
        let virtualLength = starts[old.count]
        let start = starts[prefix]
        let end = starts[old.count - suffix]
        let replacement = NSMutableAttributedString()
        middle.forEach { replacement.append($0.text) }

        // 换算到真实 storage（末尾少一个换行）
        var range = NSRange(location: start, length: end - start)
        if suffix == 0 {
            let oldReal = max(virtualLength - 1, 0)
            let newVirtual = start + replacement.length
            let newReal = max(newVirtual - 1, 0)
            let lo = min(start, oldReal, newReal)
            if lo < start {
                // 前缀最后一块的换行在真实文本里被删过（或需要删掉），把它一起换掉
                let lastPrefix = pieces[prefix - 1].text
                replacement.insert(lastPrefix.attributedSubstring(
                    from: NSRange(location: lastPrefix.length - (start - lo), length: start - lo)), at: 0)
            }
            let keep = newReal - lo
            if replacement.length > keep {
                replacement.deleteCharacters(in: NSRange(location: keep, length: replacement.length - keep))
            }
            range = NSRange(location: lo, length: oldReal - lo)
        }

        if range.length > 0 || replacement.length > 0 {
            storage.beginEditing()
            storage.replaceCharacters(in: range, with: replacement)
            storage.endEditing()
        }

        pieces.replaceSubrange(prefix..<(old.count - suffix), with: middle)
        blocks = newBlocks
        rebuildIndex()
        return Update(renderedBlocks: middle.count, replacedRange: range)
    }

    /// 只重渲染满足条件的块（远程图片加载完成时用），其余块不动
    @discardableResult
    func rerender(where predicate: (MarkdownBlock) -> Bool, renderer: ReaderRenderer, storage: NSTextStorage) -> Int {
        let targets = blocks.indices.filter { predicate(blocks[$0]) }
        guard !targets.isEmpty else { return 0 }
        let realLength = storage.length
        storage.beginEditing()
        // 从后往前换，前面片段的位置不受影响
        for i in targets.reversed() {
            let piece = renderer.renderPiece(blocks[i], isFirst: i == 0)
            var range = NSRange(location: starts[i], length: pieces[i].text.length)
            var text = piece.text
            if i == blocks.count - 1 {
                // 最后一块在 storage 里没有末尾换行
                range.length = realLength - range.location
                text = text.attributedSubstring(from: NSRange(location: 0, length: max(text.length - 1, 0)))
            }
            storage.replaceCharacters(in: range, with: text)
            pieces[i] = piece
        }
        storage.endEditing()
        rebuildIndex()
        return targets.count
    }

    private func rebuildIndex() {
        starts = [0]
        starts.reserveCapacity(pieces.count + 1)
        var headings: [(id: String, location: Int)] = []
        for (block, piece) in zip(blocks, pieces) {
            let base = starts[starts.count - 1]
            headings += zip(block.renderedHeadingIDs, piece.headingOffsets).map { ($0, base + $1) }
            starts.append(base + piece.text.length)
        }
        self.headings = headings
    }

    /// 某个复选框（storage 位置 + 块内序号）对应的源行号与当前勾选状态
    func task(at location: Int, ordinal: Int) -> (line: Int, checked: Bool)? {
        // 最后一个起点 <= location 的片段
        var lo = 0, hi = pieces.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= location { lo = mid } else { hi = mid - 1 }
        }
        guard blocks.indices.contains(lo) else { return nil }
        let items = blocks[lo].renderedTaskItems
        guard items.indices.contains(ordinal), let line = items[ordinal].sourceLine else { return nil }
        return (line, items[ordinal].checkbox ?? false)
    }
}
