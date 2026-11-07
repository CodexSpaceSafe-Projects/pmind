import Foundation

public struct PlacedTopic: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var frame: CGRect
    public let depth: Int
    public let color: BranchColor
    public let left: Bool
    public let hasHiddenChildren: Bool

    public var foldBadgeFrame: CGRect? {
        guard hasHiddenChildren else { return nil }
        return CGRect(x: left ? frame.minX - 7 : frame.maxX - 7, y: frame.midY - 7, width: 14, height: 14)
    }
}

public struct MapEdge: Equatable, Sendable {
    public var start: CGPoint
    public var control1: CGPoint
    public var control2: CGPoint
    public var end: CGPoint
    public let color: BranchColor
}

public struct MapGeometry: Equatable, Sendable {
    public var topics: [PlacedTopic]
    public var edges: [MapEdge]
    public var size: CGSize
    public func topic(_ id: UUID) -> PlacedTopic? { topics.first { $0.id == id } }
    public func hitTest(_ point: CGPoint) -> UUID? { topics.last { $0.frame.contains(point) }?.id }
    /// Uses layout metadata only; never searches the document tree for each placed node.
    public func foldBadgeHitTest(_ point: CGPoint) -> UUID? {
        topics.last { $0.foldBadgeFrame?.insetBy(dx: -1, dy: -1).contains(point) == true }?.id
    }
}

public enum MapLayoutEngine {
    public typealias Measure = (String, Bool) -> CGSize

    public static func layout(_ map: MindMap, measure: Measure) -> MapGeometry {
        let gap: CGFloat = 64, spacing: CGFloat = 20, margin: CGFloat = 64
        var sizes: [UUID: CGSize] = [:], heights: [UUID: CGFloat] = [:]
        func prepare(_ topic: Topic, root: Bool = false) -> CGFloat {
            let measured = measure(topic.title.isEmpty ? " " : topic.title, root)
            let size = CGSize(width: max(88, measured.width + 36), height: max(40, measured.height + 24))
            sizes[topic.id] = size
            let children = topic.isCollapsed ? [] : topic.children
            let height = children.reduce(CGFloat.zero) { $0 + prepare($1) } + CGFloat(max(0, children.count - 1)) * spacing
            heights[topic.id] = max(size.height, height)
            return heights[topic.id]!
        }
        _ = prepare(map.root, root: true)
        let rootSize = sizes[map.root.id]!
        let rootFrame = CGRect(x: -rootSize.width / 2, y: -rootSize.height / 2, width: rootSize.width, height: rootSize.height)
        var nodes = [PlacedTopic(id: map.root.id, frame: rootFrame, depth: 0, color: .blue, left: false,
                                hasHiddenChildren: map.root.isCollapsed && !map.root.children.isEmpty)]
        var edges: [MapEdge] = []
        func connect(_ parent: CGRect, _ child: CGRect, left: Bool, color: BranchColor, rootPort: CGFloat? = nil) {
            let start = CGPoint(x: left ? parent.minX : parent.maxX, y: rootPort ?? parent.midY)
            let end = CGPoint(x: left ? child.maxX : child.minX, y: child.midY)
            let bend = (end.x - start.x) * 0.5
            edges.append(MapEdge(start: start, control1: CGPoint(x: start.x + bend, y: start.y),
                                 control2: CGPoint(x: end.x - bend, y: end.y), end: end, color: color))
        }
        func place(_ topic: Topic, parent: CGRect, top: CGFloat, left: Bool, depth: Int,
                   color inherited: BranchColor, rootPort: CGFloat? = nil) {
            let color = topic.color ?? inherited
            let size = sizes[topic.id]!, height = heights[topic.id]!
            let frame = CGRect(x: left ? parent.minX - gap - size.width : parent.maxX + gap,
                               y: top + (height - size.height) / 2, width: size.width, height: size.height)
            nodes.append(PlacedTopic(id: topic.id, frame: frame, depth: depth, color: color, left: left,
                                     hasHiddenChildren: topic.isCollapsed && !topic.children.isEmpty))
            connect(parent, frame, left: left, color: color, rootPort: rootPort)
            guard !topic.isCollapsed else { return }
            let total = topic.children.reduce(CGFloat.zero) { $0 + heights[$1.id]! } + CGFloat(max(0, topic.children.count - 1)) * spacing
            var cursor = frame.midY - total / 2
            for child in topic.children {
                place(child, parent: frame, top: cursor, left: left, depth: depth + 1, color: color)
                cursor += heights[child.id]! + spacing
            }
        }
        if !map.root.isCollapsed {
            for left in [false, true] {
                let branches = map.root.children.enumerated().filter { index, _ in
                    (map.layout == .mindMap && index % 2 == 1) == left
                }
                let total = branches.reduce(CGFloat.zero) { $0 + heights[$1.element.id]! } + CGFloat(max(0, branches.count - 1)) * spacing
                var cursor = -total / 2
                for (position, branch) in branches.enumerated() {
                    let port = rootFrame.minY + rootFrame.height * CGFloat(position + 1) / CGFloat(branches.count + 1)
                    place(branch.element, parent: rootFrame, top: cursor, left: left, depth: 1,
                          color: BranchColor.allCases[branch.offset % BranchColor.allCases.count], rootPort: port)
                    cursor += heights[branch.element.id]! + spacing
                }
            }
        }
        let bounds = nodes.reduce(rootFrame) { $0.union($1.frame) }
        let dx = margin - bounds.minX, dy = margin - bounds.minY
        for i in nodes.indices { nodes[i].frame = nodes[i].frame.offsetBy(dx: dx, dy: dy) }
        func offset(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + dx, y: point.y + dy) }
        for i in edges.indices {
            edges[i].start = offset(edges[i].start); edges[i].end = offset(edges[i].end)
            edges[i].control1 = offset(edges[i].control1); edges[i].control2 = offset(edges[i].control2)
        }
        return MapGeometry(topics: nodes, edges: edges,
                           size: CGSize(width: bounds.width + margin * 2, height: bounds.height + margin * 2))
    }
}
