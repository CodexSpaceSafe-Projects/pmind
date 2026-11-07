import AppKit
import SwiftUI
import Testing
import MindMapCore
@testable import PMindApp

@MainActor
struct EditorSessionTests {
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
}
