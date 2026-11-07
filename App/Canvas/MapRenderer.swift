import AppKit
import MindMapCore

extension BranchColor {
    var nsColor: NSColor {
        switch self {
        case .blue: .systemBlue
        case .green: .systemGreen
        case .orange: .systemOrange
        case .purple: .systemPurple
        case .pink: .systemPink
        case .teal: .systemTeal
        }
    }
    var title: String {
        switch self {
        case .blue: "蓝色"
        case .green: "绿色"
        case .orange: "橙色"
        case .purple: "紫色"
        case .pink: "粉色"
        case .teal: "青色"
        }
    }
}

@MainActor
enum MapRenderer {
    static func canvasGeometry(_ map: MindMap) -> MapGeometry {
        // Workspace around the map lets Center preserve zoom even for a small document.
        var geometry = MapLayoutEngine.layout(map, measure: measure)
        let padding: CGFloat = 4000
        for i in geometry.topics.indices { geometry.topics[i].frame = geometry.topics[i].frame.offsetBy(dx: padding, dy: padding) }
        func shifted(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + padding, y: point.y + padding) }
        for i in geometry.edges.indices {
            geometry.edges[i].start = shifted(geometry.edges[i].start)
            geometry.edges[i].end = shifted(geometry.edges[i].end)
            geometry.edges[i].control1 = shifted(geometry.edges[i].control1)
            geometry.edges[i].control2 = shifted(geometry.edges[i].control2)
        }
        geometry.size.width += padding * 2; geometry.size.height += padding * 2
        return geometry
    }
    static func font(root: Bool) -> NSFont {
        .systemFont(ofSize: root ? 20 : 14, weight: root ? .semibold : .regular)
    }

    static func attributes(root: Bool) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        return [.font: font(root: root), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
    }

    static func measure(_ title: String, _ root: Bool) -> CGSize {
        let bounds = (title as NSString).boundingRect(
            with: CGSize(width: 240, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes(root: root)
        )
        return CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    static func draw(map: MindMap, geometry: MapGeometry, selection: UUID? = nil) {
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: geometry.size)).fill()
        for edge in geometry.edges {
            let path = NSBezierPath()
            path.move(to: edge.start)
            path.curve(to: edge.end, controlPoint1: edge.control1, controlPoint2: edge.control2)
            path.lineWidth = 2; edge.color.nsColor.withAlphaComponent(0.7).setStroke(); path.stroke()
        }
        var topics: [UUID: Topic] = [:]
        func index(_ topic: Topic) { topics[topic.id] = topic; topic.children.forEach(index) }
        index(map.root)
        for node in geometry.topics {
            guard let topic = topics[node.id] else { continue }
            let root = node.depth == 0
            let path = NSBezierPath(roundedRect: node.frame, xRadius: root ? 14 : 9, yRadius: root ? 14 : 9)
            node.color.nsColor.withAlphaComponent(root ? 0.15 : 0.07).setFill(); path.fill()
            (node.id == selection ? NSColor.controlAccentColor : node.color.nsColor.withAlphaComponent(0.45)).setStroke()
            path.lineWidth = node.id == selection ? 2.5 : 1; path.stroke()
            let content = node.frame.insetBy(dx: 18, dy: 12)
            (topic.title as NSString).draw(with: content, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                            attributes: attributes(root: root))
            if let badge = node.foldBadgeFrame {
                NSColor.textBackgroundColor.setFill(); NSBezierPath(ovalIn: badge).fill()
                node.color.nsColor.setStroke(); NSBezierPath(ovalIn: badge).stroke()
                let plus = NSBezierPath()
                plus.move(to: CGPoint(x: badge.midX - 3, y: badge.midY)); plus.line(to: CGPoint(x: badge.midX + 3, y: badge.midY))
                plus.move(to: CGPoint(x: badge.midX, y: badge.midY - 3)); plus.line(to: CGPoint(x: badge.midX, y: badge.midY + 3))
                plus.stroke()
            }
            if !topic.notes.isEmpty {
                let mark = NSBezierPath(ovalIn: CGRect(x: node.frame.maxX - 9, y: node.frame.maxY - 9, width: 4, height: 4))
                NSColor.secondaryLabelColor.setFill(); mark.fill()
            }
        }
    }
}
