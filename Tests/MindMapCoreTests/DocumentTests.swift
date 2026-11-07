import Foundation
import Testing
@testable import MindMapCore

struct DocumentTests {
    @Test func nativeRoundTrip() throws {
        var map = MindMap.welcome
        map.root.title = "中文\n多行标题"
        map.root.notes = "第一行\n第二行"
        map.root.children[0].color = .pink
        map.root.children[0].isCollapsed = true
        map.layout = .rightTree
        #expect(try DocumentCodec.decode(DocumentCodec.encode(map)) == map)
    }

    @Test func rejectsNewVersionBeforeBodyDecode() throws {
        let data = Data(#"{"format":"pmind","version":99,"root":"unknown schema"}"#.utf8)
        #expect(throws: MapError.unsupportedVersion(99)) { try DocumentCodec.decode(data) }
    }

    @Test func rejectsOtherProductsAndDuplicateIDs() throws {
        #expect(throws: MapError.invalidFormat) {
            try DocumentCodec.decode(Data(#"{"format":"wmind","version":1}"#.utf8))
        }
        let child = Topic(title: "duplicate")
        #expect(throws: MapError.duplicateID) {
            try DocumentCodec.encode(MindMap(root: Topic(title: "root", children: [child, child])))
        }
    }

    @Test func limitsFileSizeDepthAndNodeCount() throws {
        #expect(throws: MapError.tooLarge) { try DocumentCodec.decode(Data(repeating: 32, count: DocumentCodec.maxBytes + 1)) }
        var topic = Topic(title: "leaf")
        for _ in 0..<129 { topic = Topic(title: "parent", children: [topic]) }
        #expect(throws: MapError.tooDeep) { try DocumentCodec.validate(MindMap(root: topic)) }
        let wide = MindMap(root: Topic(title: "root", children: (0..<10_000).map { Topic(title: "\($0)") }))
        #expect(throws: MapError.tooManyTopics) { try DocumentCodec.validate(wide) }
    }

    @Test func searchIncludesNotesAndRevealsAncestors() throws {
        let leaf = Topic(title: "隐藏的想法", notes: "线索")
        let branch = Topic(title: "branch", isCollapsed: true, children: [leaf])
        var map = MindMap(root: Topic(title: "root", isCollapsed: true, children: [branch]))
        #expect(map.search("线索") == [leaf.id])
        #expect(map.search("  ").isEmpty)
        map.reveal(leaf.id)
        #expect(map.root.visibleTopics.map(\.id).contains(leaf.id))
    }
}
