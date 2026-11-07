import Foundation
import Testing
@testable import MindMapCore

struct MarkdownTests {
    @Test func mixedHeadingsAndListsKeepEverySection() throws {
        let text = """
        # 产品
        ## 编辑
        - 新建
          - 子主题
        - 删除
        ## 导出
        - PDF
        - PNG
        ## 本地文件
        - 保存
        """
        let root = try MarkdownCodec.decode(text).root
        #expect(root.title == "产品")
        #expect(root.children.map(\.title) == ["编辑", "导出", "本地文件"])
        #expect(root.children[0].children[0].children[0].title == "子主题")
    }

    @Test func codeFencesAndEscapedHeadingsRemainLiteral() throws {
        let root = try MarkdownCodec.decode("# Root\n```swift\n# code\n- literal\n```\n\\# literal heading\n## Real").root
        #expect(root.children.map(\.title) == ["Real"])
        #expect(root.notes.contains("# code"))
        #expect(root.notes.contains("- literal"))
        #expect(root.notes.contains("\\# literal heading"))
    }

    @Test func variableIndentAndSkippedHeadingLevelsDoNotInventNodes() throws {
        let root = try MarkdownCodec.decode("# Root\n#### Section\n- One\n    - Two\n  - Three\n").root
        #expect(root.children.count == 1)
        #expect(root.children[0].title == "Section")
        #expect(root.children[0].children[0].children.map(\.title) == ["Two", "Three"])
    }

    @Test func markdownRoundTripPreservesTextAndCollapsedDescendants() throws {
        let map = MindMap(root: Topic(title: "计划 #1\n第二行", notes: "中文备注\n下一行", children: [
            Topic(title: "[链接] & <br> \\ path", notes: "备注", isCollapsed: true,
                  children: [Topic(title: "*重要* _内容_")]),
            Topic(title: "", notes: ""),
        ]))
        let imported = try MarkdownCodec.decode(MarkdownCodec.encode(map))
        func content(_ topic: Topic) -> [String] { [topic.title, topic.notes] + topic.children.flatMap(content) }
        #expect(content(imported.root) == content(map.root))
        #expect(imported.root.count == map.root.count)
    }

    @Test func multipleRootsAndPlainNotesAreNotDiscarded() throws {
        let map = try MarkdownCodec.decode("Introduction\n# One\n# Two", title: "Outline")
        #expect(map.root.title == "Outline")
        #expect(map.root.notes == "Introduction")
        #expect(map.root.children.map(\.title) == ["One", "Two"])
    }

    @Test func roundTripsAtNativeNodeAndDepthLimits() throws {
        let wide = MindMap(root: Topic(title: "root", children: (0..<9_999).map { Topic(title: "\($0)") }))
        _ = try DocumentCodec.encode(wide)
        let imported = try MarkdownCodec.decode(MarkdownCodec.encode(wide))
        #expect(imported.root.count == wide.root.count)
        #expect(imported.root.children.map(\.title) == wide.root.children.map(\.title))

        var root = Topic(title: "leaf")
        for _ in 0..<128 { root = Topic(title: "parent", children: [root]) }
        let deep = MindMap(root: root)
        _ = try DocumentCodec.encode(deep)
        #expect(try MarkdownCodec.decode(MarkdownCodec.encode(deep)).root.count == 129)
    }

    @Test func rejectsLimitsExceededWithOrWithoutPromotedRoot() throws {
        let items = (0..<10_000).map { "- \($0)" }.joined(separator: "\n")
        #expect(throws: MapError.tooManyTopics) { try MarkdownCodec.decode("# Root\n" + items) }
        #expect(throws: MapError.tooManyTopics) { try MarkdownCodec.decode(items) }

        var root = Topic(title: "leaf")
        for _ in 0..<128 { root = Topic(title: "parent", children: [root]) }
        let text = MarkdownCodec.encode(MindMap(root: root))
        #expect(throws: MapError.tooDeep) { try MarkdownCodec.decode("Introduction\n" + text) }
        root = Topic(title: "extra", children: [root])
        #expect(throws: MapError.tooDeep) { try MarkdownCodec.decode(MarkdownCodec.encode(MindMap(root: root))) }
    }

    @Test func preservesTabsInTitlesAndNotesWhileParsingIndentedLists() throws {
        let map = MindMap(root: Topic(title: "\t中文\t标题\t", notes: "\tkey\tvalue\n    \t尾部\t", children: [
            Topic(title: "\tchild\t", notes: "代码\t缩进", children: [Topic(title: "leaf")]),
        ]))
        let imported = try MarkdownCodec.decode(MarkdownCodec.encode(map))
        #expect(imported.root.title == map.root.title)
        #expect(imported.root.notes == map.root.notes)
        #expect(imported.root.children[0].title == map.root.children[0].title)
        #expect(imported.root.children[0].notes == map.root.children[0].notes)

        let indented = try MarkdownCodec.decode("# Root\n- Parent\n\t- Child\ttext\n\t  > key\tvalue")
        #expect(indented.root.children[0].children[0].title == "Child\ttext")
        #expect(indented.root.children[0].children[0].notes == "key\tvalue")
    }
}
