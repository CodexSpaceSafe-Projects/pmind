import Foundation

public enum MapCommand: Sendable {
    case addChild(UUID), addSibling(UUID), rename(UUID, String), notes(UUID, String)
    case delete(UUID), toggleFold(UUID), color(UUID, BranchColor?), layout(MapLayout)
    /// Index refers to the destination's child array BEFORE removing the source.
    case move(UUID, parent: UUID, index: Int)
    case paste(Topic, parent: UUID)
}

public struct EditResult: Equatable, Sendable {
    public let selection: UUID
    public let startsEditing: Bool
}

extension MindMap {
    /// Transactional: invalid/no-op commands leave the complete document unchanged.
    @discardableResult
    public mutating func apply(_ command: MapCommand) throws -> EditResult? {
        var next = self
        var selection = root.id
        var startsEditing = false
        func require(_ id: UUID) throws {
            guard next.root.topic(id) != nil else { throw MapError.missingTopic }
            selection = id
        }
        switch command {
        case .addChild(let id):
            try require(id)
            let topic = Topic(title: "新主题")
            next.root.update(id) { $0.isCollapsed = false; $0.children.append(topic) }
            selection = topic.id; startsEditing = true
        case .addSibling(let id):
            try require(id)
            guard let parent = next.root.parent(of: id),
                  let index = parent.children.firstIndex(where: { $0.id == id }) else { return nil }
            let topic = Topic(title: "新主题")
            next.root.update(parent.id) { $0.children.insert(topic, at: index + 1) }
            selection = topic.id; startsEditing = true
        case .rename(let id, let title):
            try require(id); next.root.update(id) { $0.title = title }
        case .notes(let id, let text):
            try require(id); next.root.update(id) { $0.notes = text }
        case .color(let id, let color):
            try require(id); next.root.update(id) { $0.color = color }
        case .layout(let layout):
            next.layout = layout
        case .toggleFold(let id):
            try require(id)
            next.root.update(id) { if !$0.children.isEmpty { $0.isCollapsed.toggle() } }
        case .delete(let id):
            try require(id)
            guard let parent = next.root.parent(of: id) else { return nil }
            next.root.update(parent.id) { $0.children.removeAll { $0.id == id } }
            selection = parent.id
        case .paste(let source, let parent):
            try require(parent)
            let topic = source.copyingWithNewIDs()
            next.root.update(parent) { $0.children.append(topic); $0.isCollapsed = false }
            selection = topic.id
        case .move(let id, let parentID, let index):
            try require(id); try require(parentID)
            guard id != root.id, let source = next.root.topic(id),
                  let oldParent = next.root.parent(of: id) else { throw MapError.invalidMove }
            guard source.topic(parentID) == nil else { throw MapError.invalidMove }
            let destinationCount = next.root.topic(parentID)!.children.count
            let clampedIndex = min(max(index, 0), destinationCount)
            let oldIndex = oldParent.children.firstIndex { $0.id == id }!
            let adjusted = clampedIndex - (oldParent.id == parentID && oldIndex < clampedIndex ? 1 : 0)
            if oldParent.id == parentID && adjusted == oldIndex { return nil }
            next.root.update(oldParent.id) { $0.children.removeAll { $0.id == id } }
            next.root.update(parentID) { $0.children.insert(source, at: adjusted); $0.isCollapsed = false }
            selection = id
        }
        guard next != self else { return nil }
        // Also bounds paste/notes/title growth before a mutation enters history.
        _ = try DocumentCodec.encode(next)
        self = next
        return EditResult(selection: selection, startsEditing: startsEditing)
    }
}
