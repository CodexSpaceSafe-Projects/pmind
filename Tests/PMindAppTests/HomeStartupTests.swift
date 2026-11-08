import Testing
@testable import PMindApp

@MainActor
struct HomeStartupTests {
    @Test func newDocumentsStartWithOneBlankCentralTopic() {
        let file = MindMapFile()
        #expect(file.map.root.title == "中心主题")
        #expect(file.map.root.children.isEmpty)
        #expect(file.map.root.count == 1)
    }
}
