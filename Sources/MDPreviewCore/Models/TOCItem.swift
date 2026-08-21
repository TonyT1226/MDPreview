import Foundation

/// 目录大纲节点模型（支持多层级嵌套）
public struct TOCItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
    public var children: [TOCItem]

    public init(id: String, level: Int, title: String, children: [TOCItem] = []) {
        self.id = id
        self.level = level
        self.title = title
        self.children = children
    }
}
