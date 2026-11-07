import Foundation

public enum MapLayout: String, Codable, CaseIterable, Sendable {
    case mindMap, rightTree
}

public enum BranchColor: String, Codable, CaseIterable, Sendable {
    case blue, green, orange, purple, pink, teal
}

public struct Topic: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCollapsed: Bool
    public var color: BranchColor?
    public var children: [Topic]

    public init(id: UUID = UUID(), title: String, notes: String = "", isCollapsed: Bool = false,
                color: BranchColor? = nil, children: [Topic] = []) {
        self.id = id; self.title = title; self.notes = notes
        self.isCollapsed = isCollapsed; self.color = color; self.children = children
    }

    public func topic(_ id: UUID) -> Topic? {
        if self.id == id { return self }
        for child in children { if let match = child.topic(id) { return match } }
        return nil
    }

    public var count: Int { 1 + children.reduce(0) { $0 + $1.count } }

    public func copyingWithNewIDs() -> Topic {
        Topic(title: title, notes: notes, isCollapsed: isCollapsed, color: color,
              children: children.map { $0.copyingWithNewIDs() })
    }

    @discardableResult
    mutating func update(_ id: UUID, _ change: (inout Topic) -> Void) -> Bool {
        if self.id == id { change(&self); return true }
        for index in children.indices {
            if children[index].update(id, change) { return true }
        }
        return false
    }

    public func parent(of id: UUID) -> Topic? {
        if children.contains(where: { $0.id == id }) { return self }
        for child in children { if let result = child.parent(of: id) { return result } }
        return nil
    }

    public var visibleTopics: [Topic] {
        [self] + (isCollapsed ? [] : children.flatMap(\.visibleTopics))
    }
}

public struct MindMap: Equatable, Sendable {
    public var root: Topic
    public var layout: MapLayout
    public init(root: Topic = Topic(title: "中心主题"), layout: MapLayout = .mindMap) {
        self.root = root; self.layout = layout
    }

    public static var welcome: MindMap {
        MindMap(root: Topic(title: "我的想法", children: [
            Topic(title: "从这里开始", children: [Topic(title: "Tab 添加子主题"), Topic(title: "Return 添加同级主题")]),
            Topic(title: "理清思路", children: [Topic(title: "拖动主题调整层级"), Topic(title: "双击编辑文字")]),
            Topic(title: "留住灵感", children: [Topic(title: "⌘S 保存到本地"), Topic(title: "导出 Markdown、图片或 PDF")]),
        ]))
    }

    public func search(_ query: String) -> [UUID] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        func visit(_ topic: Topic) -> [UUID] {
            let match = topic.title.localizedStandardContains(text) || topic.notes.localizedStandardContains(text)
            return (match ? [topic.id] : []) + topic.children.flatMap(visit)
        }
        return visit(root)
    }

    public mutating func reveal(_ id: UUID) {
        func expand(_ topic: inout Topic) -> Bool {
            if topic.id == id { return true }
            for index in topic.children.indices {
                if expand(&topic.children[index]) { topic.isCollapsed = false; return true }
            }
            return false
        }
        _ = expand(&root)
    }
}
