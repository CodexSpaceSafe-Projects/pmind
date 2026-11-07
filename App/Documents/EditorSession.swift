import AppKit
import SwiftUI
import MindMapCore
import OSLog

enum ViewportAction { case fit, center, zoomIn, zoomOut, reveal(UUID) }

/// One instance per document window. Document data lives only in the FileDocument binding.
@MainActor
final class EditorSession: ObservableObject {
    private let logger = Logger(subsystem: "app.pmind.mac", category: "Commands")
    private var file: Binding<MindMapFile>
    weak var undoManager: UndoManager?
    @Published var selection: UUID
    @Published var editingRequest: UUID?
    @Published var viewportRequest: UUID = UUID()
    private(set) var viewportAction: ViewportAction = .fit
    @Published var zoom: CGFloat = 1
    @Published var query = ""
    @Published var error: String?

    init(file: Binding<MindMapFile>) {
        self.file = file; self.selection = file.wrappedValue.map.root.id
    }
    var map: MindMap { file.wrappedValue.map }
    var selectedTopic: Topic? { map.root.topic(selection) }
    var canDelete: Bool { selection != map.root.id && selectedTopic != nil }
    var matches: [UUID] { map.search(query) }

    func perform(_ command: MapCommand, label: String) {
        do {
            var next = map
            guard let result = try next.apply(command) else { return }
            replace(next, selection: result.selection, label: label)
            logger.debug("Document command completed")
            if result.startsEditing { editingRequest = result.selection }
            request(.reveal(result.selection))
        } catch {
            logger.error("Document command rejected")
            self.error = error.localizedDescription
        }
    }

    private func replace(_ map: MindMap, selection: UUID, label: String) {
        let previous = self.map, oldSelection = self.selection
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.replace(previous, selection: oldSelection, label: label) }
        }
        undoManager?.setActionName(label)
        objectWillChange.send()
        file.wrappedValue.map = map
        editingRequest = nil
        self.selection = map.root.topic(selection) == nil ? map.root.id : selection
    }

    func select(_ id: UUID, reveal: Bool = false) {
        guard map.root.topic(id) != nil else { return }
        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.keyWindow?.makeFirstResponder(nil) }
        editingRequest = nil
        if reveal {
            var next = map; next.reveal(id)
            if next != map { replace(next, selection: id, label: "展开主题") }
        }
        selection = id
        if reveal { request(.reveal(id)) }
    }

    func request(_ action: ViewportAction) { viewportAction = action; viewportRequest = UUID() }
    func edit() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        editingRequest = selection
    }
    func addChild() { perform(.addChild(selection), label: "添加子主题") }
    func addSibling() { perform(.addSibling(selection), label: "添加同级主题") }
    func delete() { perform(.delete(selection), label: "删除主题") }
    func fold() { perform(.toggleFold(selection), label: "折叠或展开") }

    func copyTopic() {
        guard let topic = selectedTopic else { return }
        do {
            let map = MindMap(root: topic)
            let data = try DocumentCodec.encode(map)
            let board = NSPasteboard.general
            board.clearContents()
            board.setData(data, forType: .init("app.pmind.subtree"))
            board.setString(MarkdownCodec.encode(map), forType: .string)
        } catch { self.error = error.localizedDescription }
    }

    func pasteTopic() {
        do {
            let board = NSPasteboard.general
            let source: Topic
            if let data = board.data(forType: .init("app.pmind.subtree")) {
                source = try DocumentCodec.decode(data).root
            } else if let text = board.string(forType: .string), !text.isEmpty {
                source = try MarkdownCodec.decode(text).root
            } else { return }
            perform(.paste(source, parent: selection), label: "粘贴主题")
        } catch { self.error = error.localizedDescription }
    }

    func selectAdjacent(_ offset: Int) {
        let ids = map.root.visibleTopics.map(\.id)
        guard let index = ids.firstIndex(of: selection) else { return }
        select(ids[min(max(index + offset, 0), ids.count - 1)], reveal: true)
    }
}
