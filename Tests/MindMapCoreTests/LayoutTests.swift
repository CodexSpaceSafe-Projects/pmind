import Foundation
import Testing
@testable import MindMapCore

struct LayoutTests {
    private let measure: MapLayoutEngine.Measure = { text, _ in
        CGSize(width: min(240, CGFloat(text.count) * 10), height: CGFloat(max(1, text.count / 24 + 1)) * 18)
    }

    @Test func bothLayoutsHaveNoOverlapsForAThousandTopics() throws {
        var map = MindMap(root: Topic(title: "中心", children: (0..<25).map { branch in
            Topic(title: "分支 \(branch)", children: (0..<39).map { Topic(title: "内容 \($0)") })
        }))
        for layout in MapLayout.allCases {
            map.layout = layout
            let geometry = MapLayoutEngine.layout(map, measure: measure)
            #expect(geometry.topics.count == 1001)
            #expect(geometry.edges.count == 1000)
            for (index, topic) in geometry.topics.enumerated() {
                #expect(topic.frame.minX >= 0 && topic.frame.minY >= 0)
                #expect(topic.frame.maxX <= geometry.size.width && topic.frame.maxY <= geometry.size.height)
                for other in geometry.topics.dropFirst(index + 1) {
                    if topic.frame.intersects(other.frame) { Issue.record("Overlapping topics \(topic.id), \(other.id)") }
                }
            }
        }
    }

    @Test func foldingRemovesOnlyVisibleGeometry() throws {
        var map = MindMap.welcome
        let branch = map.root.children[0]
        try map.apply(.toggleFold(branch.id))
        let geometry = MapLayoutEngine.layout(map, measure: measure)
        #expect(geometry.topic(branch.id) != nil)
        #expect(geometry.topic(branch.children[0].id) == nil)
        #expect(map.root.topic(branch.children[0].id) != nil)
    }

    @Test func sidesAreStableAcrossTitleEdits() throws {
        var map = MindMap.welcome
        let before = MapLayoutEngine.layout(map, measure: measure)
        let id = map.root.children[0].id
        try map.apply(.rename(id, String(repeating: "长标题", count: 40)))
        let after = MapLayoutEngine.layout(map, measure: measure)
        #expect(before.topics.map(\.left) == after.topics.map(\.left))
    }

    @Test func rootPortsAreDistributedAndHitTestingMatchesGeometry() throws {
        let map = MindMap.welcome
        let geometry = MapLayoutEngine.layout(map, measure: measure)
        let root = try #require(geometry.topic(map.root.id))
        let ports = geometry.edges.filter { root.frame.insetBy(dx: -0.1, dy: -0.1).contains($0.start) }.map(\.start)
        #expect(Set(ports.map { "\($0.x),\($0.y)" }).count == map.root.children.count)
        #expect(geometry.hitTest(CGPoint(x: root.frame.midX, y: root.frame.midY)) == map.root.id)
        #expect(geometry.hitTest(CGPoint(x: -1, y: -1)) == nil)
    }
}
