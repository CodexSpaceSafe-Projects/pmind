import Foundation
import Testing
@testable import MindMapCore

struct CommandTests {
    @Test func addsSiblingsAndChildrenWithStableSelection() throws {
        var map = MindMap()
        let root = map.root.id
        #expect(try map.apply(.addSibling(root)) == nil)
        let childResult = try map.apply(.addChild(root))
        let child = try #require(childResult)
        #expect(child.startsEditing)
        #expect(map.root.children[0].id == child.selection)
        let siblingResult = try map.apply(.addSibling(child.selection))
        let sibling = try #require(siblingResult)
        #expect(map.root.children[1].id == sibling.selection)
        #expect(map.root.id == root)
    }

    @Test func noOpsDoNotProduceHistoryEntries() throws {
        var map = MindMap()
        let before = map
        #expect(try map.apply(.rename(map.root.id, map.root.title)) == nil)
        #expect(try map.apply(.delete(map.root.id)) == nil)
        #expect(try map.apply(.toggleFold(map.root.id)) == nil)
        #expect(try map.apply(.layout(map.layout)) == nil)
        #expect(map == before)
    }

    @Test func foldsRetainChildrenAndAddingUnfolds() throws {
        var map = MindMap.welcome
        let id = map.root.children[0].id
        let count = map.root.count
        try map.apply(.toggleFold(id))
        #expect(map.root.count == count)
        #expect(map.root.visibleTopics.count < count)
        try map.apply(.addChild(id))
        #expect(map.root.topic(id)?.isCollapsed == false)
    }

    @Test func deletingSubtreeSelectsParent() throws {
        var map = MindMap.welcome
        let branch = map.root.children[0]
        let result = try map.apply(.delete(branch.id))
        #expect(result?.selection == map.root.id)
        #expect(map.root.topic(branch.children[0].id) == nil)
    }

    @Test func cyclicMoveFailsAtomically() throws {
        var map = MindMap.welcome
        let before = map
        let branch = map.root.children[0]
        #expect(throws: MapError.invalidMove) {
            try map.apply(.move(branch.id, parent: branch.children[0].id, index: 0))
        }
        #expect(map == before)
        #expect(throws: MapError.invalidMove) { try map.apply(.move(map.root.id, parent: branch.id, index: 0)) }
        #expect(map == before)
    }

    @Test func siblingReorderUsesPreRemovalIndex() throws {
        var map = MindMap.welcome
        let original = map.root.children.map(\.id)
        #expect(try map.apply(.move(original[0], parent: map.root.id, index: 1)) == nil)
        try map.apply(.move(original[0], parent: map.root.id, index: 3))
        #expect(map.root.children.map(\.id) == [original[1], original[2], original[0]])
        try map.apply(.move(original[0], parent: map.root.id, index: 0))
        #expect(map.root.children.map(\.id) == original)
    }

    @Test func crossParentMoveKeepsContentAndUnfoldsDestination() throws {
        var map = MindMap.welcome
        let source = map.root.children[0].children[0]
        let parent = map.root.children[1].id
        try map.apply(.toggleFold(parent))
        try map.apply(.move(source.id, parent: parent, index: 0))
        #expect(map.root.topic(parent)?.children[0] == source)
        #expect(map.root.topic(parent)?.isCollapsed == false)
        #expect(map.root.parent(of: source.id)?.id == parent)
    }

    @Test func pasteRegeneratesAllIdentifiers() throws {
        var map = MindMap.welcome
        let source = map.root
        try map.apply(.paste(source, parent: map.root.id))
        let pasted = try #require(map.root.children.last)
        #expect(pasted.id != source.id)
        #expect(pasted.children[0].id != source.children[0].id)
        #expect(pasted.count == source.count)
        try DocumentCodec.validate(map)
    }

    @Test func invalidAndOversizeEditsLeaveDocumentUntouched() throws {
        var map = MindMap.welcome
        let before = map
        #expect(throws: MapError.missingTopic) { try map.apply(.rename(UUID(), "missing")) }
        #expect(throws: MapError.tooLarge) { try map.apply(.notes(map.root.id, String(repeating: "x", count: DocumentCodec.maxBytes))) }
        #expect(map == before)
    }

    @Test func contentAndStyleCanBeCleared() throws {
        var map = MindMap.welcome
        let id = map.root.children[0].id
        try map.apply(.rename(id, ""))
        try map.apply(.notes(id, "note")); try map.apply(.notes(id, ""))
        try map.apply(.color(id, .pink)); try map.apply(.color(id, nil))
        #expect(map.root.topic(id)?.title == "")
        #expect(map.root.topic(id)?.notes == "")
        #expect(map.root.topic(id)?.color == nil)
    }
}
