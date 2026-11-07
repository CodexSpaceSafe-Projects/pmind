import AppKit
import MindMapCore

@MainActor
final class MapCanvasView: NSView, NSTextFieldDelegate {
    weak var session: EditorSession?
    private(set) var map: MindMap
    private(set) var geometry: MapGeometry
    var lastRequest: UUID?
    private var field: NSTextField?
    private var editingID: UUID?
    private var pressedID: UUID?
    private var pressPoint = CGPoint.zero
    private var dragging = false
    private var panning = false
    private var spaceHeld = false
    private var drop: (parent: UUID, index: Int, hovered: UUID, zone: Int)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        spaceHeld = false; panning = false; dragging = false; pressedID = nil; drop = nil
        NSCursor.arrow.set()
        return super.resignFirstResponder()
    }

    init(session: EditorSession, map: MindMap) {
        self.session = session; self.map = map
        geometry = MapRenderer.canvasGeometry(map)
        super.init(frame: CGRect(origin: .zero, size: geometry.size))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("思维导图画布")
        setAccessibilityHelp("使用 Tab 新建子主题，Return 新建同级主题，方向键浏览，Command E 编辑标题。大纲提供可访问的主题列表。")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(map: MindMap) {
        guard self.map != map else { return }
        let anchor = session.flatMap { geometry.topic($0.selection)?.frame }
        self.map = map
        geometry = MapRenderer.canvasGeometry(map)
        setFrameSize(geometry.size)
        if let anchor, let id = session?.selection, let next = geometry.topic(id)?.frame,
           let clip = enclosingScrollView?.contentView {
            clip.scroll(to: CGPoint(x: clip.bounds.minX + next.midX - anchor.midX,
                                    y: clip.bounds.minY + next.midY - anchor.midY))
        }
        if let id = editingID, map.root.topic(id) == nil { cancelEditing() }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        MapRenderer.draw(map: map, geometry: geometry, selection: session?.selection)
        if let drop, let target = geometry.topic(drop.hovered) {
            NSColor.controlAccentColor.setStroke()
            let path: NSBezierPath
            if drop.zone == 0 { path = NSBezierPath(roundedRect: target.frame.insetBy(dx: -4, dy: -4), xRadius: 10, yRadius: 10) }
            else {
                let y = drop.zone < 0 ? target.frame.minY - 8 : target.frame.maxY + 8
                path = NSBezierPath(); path.move(to: CGPoint(x: target.frame.minX, y: y))
                path.line(to: CGPoint(x: target.frame.maxX, y: y))
            }
            path.lineWidth = 3; path.stroke()
        }
    }

    func navigate(_ action: ViewportAction) {
        guard let scroll = enclosingScrollView else { return }
        switch action {
        case .fit:
            let available = scroll.contentSize
            let content = geometry.topics.reduce(CGRect.null) { $0.union($1.frame) }.insetBy(dx: -64, dy: -64)
            let zoom = min(1, max(0.2, min(available.width / content.width, available.height / content.height)))
            scroll.magnification = zoom
            center(CGPoint(x: content.midX, y: content.midY))
        case .center:
            if let root = geometry.topic(map.root.id) { center(CGPoint(x: root.frame.midX, y: root.frame.midY)) }
        case .zoomIn, .zoomOut:
            let factor: CGFloat
            if case .zoomIn = action { factor = 1.2 } else { factor = 1 / 1.2 }
            let anchor = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
            scroll.setMagnification(min(3, max(0.2, scroll.magnification * factor)), centeredAt: anchor)
        case .reveal(let id):
            if let node = geometry.topic(id), !visibleRect.insetBy(dx: 24, dy: 24).contains(node.frame) {
                center(CGPoint(x: node.frame.midX, y: node.frame.midY))
            }
        }
        session?.zoom = scroll.magnification
    }

    private func center(_ point: CGPoint) {
        guard let scroll = enclosingScrollView else { return }
        let size = visibleRect.size
        scroll.contentView.scroll(to: CGPoint(x: max(0, point.x - size.width / 2), y: max(0, point.y - size.height / 2)))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    override func mouseDown(with event: NSEvent) {
        if field != nil { finishEditing() }
        window?.makeFirstResponder(self)
        pressPoint = convert(event.locationInWindow, from: nil)
        panning = spaceHeld || event.buttonNumber == 2
        pressedID = panning ? nil : geometry.hitTest(pressPoint)
        dragging = false; drop = nil
        if !panning, let folded = geometry.topics.first(where: { node in
            guard map.root.topic(node.id)?.isCollapsed == true else { return false }
            let badge = CGRect(x: node.left ? node.frame.minX - 8 : node.frame.maxX - 8,
                               y: node.frame.midY - 8, width: 16, height: 16)
            return badge.contains(pressPoint)
        }) {
            session?.select(folded.id); session?.fold(); pressedID = nil
            return
        }
        if let id = pressedID {
            session?.select(id)
            if event.clickCount == 2 { beginEditing(id) }
        }
        needsDisplay = true
    }

    override func otherMouseDown(with event: NSEvent) { mouseDown(with: event) }
    override func otherMouseDragged(with event: NSEvent) { mouseDragged(with: event) }
    override func otherMouseUp(with event: NSEvent) { mouseUp(with: event) }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if panning, let scroll = enclosingScrollView {
            let origin = scroll.contentView.bounds.origin
            scroll.contentView.scroll(to: CGPoint(x: origin.x + pressPoint.x - point.x, y: origin.y + pressPoint.y - point.y))
            scroll.reflectScrolledClipView(scroll.contentView)
            return
        }
        guard field == nil, let source = pressedID, source != map.root.id else { return }
        if hypot(point.x - pressPoint.x, point.y - pressPoint.y) > 5 { dragging = true }
        guard dragging else { return }
        _ = autoscroll(with: event)
        drop = destination(source: source, point: point)
        needsDisplay = true
    }

    private func destination(source: UUID, point: CGPoint) -> (UUID, Int, UUID, Int)? {
        guard let hover = geometry.hitTest(point), let target = geometry.topic(hover),
              map.root.topic(source)?.topic(hover) == nil else { return nil }
        let zone = point.y < target.frame.minY + target.frame.height * 0.25 ? -1 :
            (point.y > target.frame.maxY - target.frame.height * 0.25 ? 1 : 0)
        if zone != 0, let parent = map.root.parent(of: hover),
           let index = parent.children.firstIndex(where: { $0.id == hover }) {
            return (parent.id, index + (zone > 0 ? 1 : 0), hover, zone)
        }
        return (hover, map.root.topic(hover)!.children.count, hover, 0)
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressedID = nil; dragging = false; panning = false; drop = nil; needsDisplay = true }
        if dragging, let source = pressedID, let drop {
            session?.perform(.move(source, parent: drop.parent, index: drop.index), label: "移动主题")
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let session else { return }
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        switch event.keyCode {
        case 48:
            if event.modifierFlags.contains(.shift), let parent = map.root.parent(of: session.selection) { session.select(parent.id, reveal: true) }
            else { session.addChild() }
        case 36, 76:
            if session.canDelete { session.addSibling() } else { session.edit() }
        case 51, 117: session.delete()
        case 126: session.selectAdjacent(-1)
        case 125: session.selectAdjacent(1)
        case 123:
            if let parent = map.root.parent(of: session.selection) { session.select(parent.id, reveal: true) }
        case 124:
            if let topic = session.selectedTopic, !topic.children.isEmpty {
                session.select(topic.children[0].id, reveal: true)
            }
        case 49: spaceHeld = true; NSCursor.openHand.set()
        case 53: pressedID = nil; dragging = false; drop = nil; needsDisplay = true
        default: super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { spaceHeld = false; NSCursor.arrow.set() } else { super.keyUp(with: event) }
    }

    @objc func copy(_ sender: Any?) { session?.copyTopic() }
    @objc func paste(_ sender: Any?) { session?.pasteTopic() }
    @objc func cut(_ sender: Any?) { if session?.canDelete == true { session?.copyTopic(); session?.delete() } }
    @objc private func addChild(_ sender: Any?) { session?.addChild() }
    @objc private func rename(_ sender: Any?) { session?.edit() }
    @objc private func removeTopic(_ sender: Any?) { session?.delete() }
    @objc private func toggleFold(_ sender: Any?) { session?.fold() }

    override func menu(for event: NSEvent) -> NSMenu? {
        if let id = geometry.hitTest(convert(event.locationInWindow, from: nil)) { session?.select(id) }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (title, action) in [("添加子主题", #selector(addChild(_:))), ("编辑标题", #selector(rename(_:))),
                                ("折叠 / 展开", #selector(toggleFold(_:))), ("复制主题", #selector(copy(_:))),
                                ("粘贴主题", #selector(paste(_:))), ("删除主题", #selector(removeTopic(_:)))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            if action == #selector(removeTopic(_:)) { item.isEnabled = session?.canDelete == true }
            if action == #selector(toggleFold(_:)) { item.isEnabled = session?.selectedTopic?.children.isEmpty == false }
            item.target = self; menu.addItem(item)
        }
        return menu
    }
}

extension MapCanvasView {
    func beginEditing(_ id: UUID) {
        guard let node = geometry.topic(id), let topic = map.root.topic(id), field == nil else { return }
        let input = NSTextField(frame: node.frame.insetBy(dx: 8, dy: 4))
        input.stringValue = topic.title; input.font = MapRenderer.font(root: node.depth == 0)
        input.alignment = .center; input.isBordered = false; input.drawsBackground = true
        input.backgroundColor = .textBackgroundColor; input.focusRingType = .exterior
        input.usesSingleLineMode = false; input.lineBreakMode = .byWordWrapping
        input.delegate = self; input.setAccessibilityLabel("主题标题")
        field = input; editingID = id; addSubview(input)
        _ = scrollToVisible(input.frame.insetBy(dx: -20, dy: -20))
        window?.makeFirstResponder(input); input.selectText(nil)
    }

    func controlTextDidEndEditing(_ obj: Notification) { finishEditing() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { cancelEditing(); return true }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else { finishEditing() }
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) { finishEditing(); session?.addChild(); return true }
        return false
    }

    private func finishEditing() {
        guard let field, let id = editingID else { return }
        let text = field.stringValue
        self.field = nil; editingID = nil; field.delegate = nil; field.removeFromSuperview()
        window?.makeFirstResponder(self)
        session?.perform(.rename(id, text), label: "编辑标题")
    }

    private func cancelEditing() {
        field?.delegate = nil; field?.removeFromSuperview(); field = nil; editingID = nil
        window?.makeFirstResponder(self)
    }
}
