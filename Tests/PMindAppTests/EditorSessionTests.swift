import AppKit
import SwiftUI
import Testing
import MindMapCore
@testable import PMindApp

@MainActor
struct EditorSessionTests {
    private final class RejectedTitleEditor: TitleEditing {
        func commitTitleEditing() -> Bool { false }
    }
    private final class Box { var file = MindMapFile(map: MindMap()) }
    private func makeSession() -> (EditorSession, Box, UndoManager) {
        let box = Box()
        let session = EditorSession(file: Binding(get: { box.file }, set: { box.file = $0 }))
        let undo = UndoManager(); undo.groupsByEvent = false; session.undoManager = undo
        return (session, box, undo)
    }

    @Test func undoRedoRestoresDocumentAndSelection() throws {
        let (session, box, undo) = makeSession()
        let before = box.file.map
        undo.beginUndoGrouping(); session.addChild(); undo.endUndoGrouping()
        let selected = session.selection
        #expect(box.file.map.root.children.count == 1)
        undo.undo()
        #expect(box.file.map == before)
        #expect(session.selection == before.root.id)
        #expect(session.editingRequest == nil)
        undo.redo()
        #expect(box.file.map.root.children.first?.id == selected)
        #expect(session.selection == selected)
    }

    @Test func noOpsHaveNoUndoAndWindowsAreIsolated() {
        let (first, firstBox, firstUndo) = makeSession()
        let (second, secondBox, secondUndo) = makeSession()
        first.delete()
        #expect(!firstUndo.canUndo)
        firstUndo.beginUndoGrouping(); first.addChild(); firstUndo.endUndoGrouping()
        #expect(firstBox.file.map.root.children.count == 1)
        #expect(secondBox.file.map.root.children.isEmpty)
        #expect(!secondUndo.canUndo)
        #expect(second.selection == secondBox.file.map.root.id)
    }

    @Test func rejectedEditsDoNotEnterUndoHistory() {
        let (session, box, undo) = makeSession()
        let before = box.file.map
        session.perform(.rename(UUID(), "invalid"), label: "invalid")
        #expect(box.file.map == before)
        #expect(!undo.canUndo)
        #expect(session.error != nil)
    }

    @Test func nativeTextMeasurementAndExportGeometryIncludeChinese() {
        let map = MindMap(root: Topic(title: "中文标题\n第二行", children: [Topic(title: "备注", notes: "内容")]))
        let geometry = MapLayoutEngine.layout(map, measure: MapRenderer.measure)
        #expect(geometry.topics.count == 2)
        #expect(MapRenderer.measure("中文标题\n第二行", true).height > MapRenderer.measure("中文标题", true).height)
        #expect(geometry.topics.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 })
    }

    @Test func addingChildCommitsCurrentTitleAndAllowsEditingTheChild() throws {
        let (session, box, undo) = makeSession()
        let canvas = MapCanvasView(session: session, map: box.file.map)
        canvas.beginEditing(session.selection)
        let input = try #require(canvas.subviews.compactMap { $0 as? NSTextField }.first)
        input.stringValue = "尚未结束的中文标题"

        undo.beginUndoGrouping(); session.addChild(); undo.endUndoGrouping()
        #expect(box.file.map.root.title == "尚未结束的中文标题")
        let child = try #require(box.file.map.root.children.first)
        #expect(session.editingRequest == child.id)
        #expect(input.superview == nil)

        canvas.update(map: box.file.map)
        canvas.beginEditing(child.id)
        let next = try #require(canvas.subviews.compactMap { $0 as? NSTextField }.first)
        #expect(next !== input)
        #expect(next.stringValue == child.title)
    }

    @Test func addingSiblingRetainsTheCommittedTitleThroughUndoRedo() throws {
        let (session, box, undo) = makeSession()
        undo.beginUndoGrouping(); session.addChild(); undo.endUndoGrouping()
        let id = session.selection
        let canvas = MapCanvasView(session: session, map: box.file.map)
        canvas.beginEditing(id)
        let input = try #require(canvas.subviews.compactMap { $0 as? NSTextField }.first)
        input.stringValue = "已完成的标题"

        undo.beginUndoGrouping(); session.addSibling(); undo.endUndoGrouping()
        let edited = box.file.map
        #expect(edited.root.topic(id)?.title == "已完成的标题")
        #expect(edited.root.children.count == 2)
        #expect(session.editingRequest == edited.root.children[1].id)
        undo.undo()
        #expect(box.file.map.root.children.count == 1)
        undo.redo()
        #expect(box.file.map == edited)
    }

    @Test func commandsOnlyCommitTheirOwnWindowsTitle() throws {
        let (first, firstBox, firstUndo) = makeSession()
        let (second, secondBox, secondUndo) = makeSession()
        let canvas = MapCanvasView(session: first, map: firstBox.file.map)
        canvas.beginEditing(first.selection)
        let input = try #require(canvas.subviews.compactMap { $0 as? NSTextField }.first)
        input.stringValue = "窗口一的草稿"

        secondUndo.beginUndoGrouping(); second.addChild(); secondUndo.endUndoGrouping()
        #expect(secondBox.file.map.root.children.count == 1)
        #expect(firstBox.file.map.root.title == "中心主题")
        #expect(input.superview === canvas)
        firstUndo.beginUndoGrouping(); first.addChild(); firstUndo.endUndoGrouping()
        #expect(firstBox.file.map.root.title == "窗口一的草稿")
    }

    @Test func rejectedPendingTitlePreventsStructuralChanges() {
        let (session, box, undo) = makeSession()
        let editor = RejectedTitleEditor()
        session.titleEditor = editor
        let before = box.file.map
        session.editingRequest = session.selection
        session.addChild()
        #expect(box.file.map == before)
        #expect(session.editingRequest == before.root.id)
        #expect(!undo.canUndo)
    }
}
