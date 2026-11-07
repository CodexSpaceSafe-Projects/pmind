import AppKit
import SwiftUI
import MindMapCore

struct MapCanvas: NSViewRepresentable {
    @ObservedObject var session: EditorSession
    let map: MindMap

    func makeNSView(context: Context) -> MapScrollView {
        let scroll = MapScrollView()
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true; scroll.scrollerStyle = .overlay
        scroll.allowsMagnification = true; scroll.minMagnification = 0.2; scroll.maxMagnification = 3
        scroll.backgroundColor = .textBackgroundColor
        let canvas = MapCanvasView(session: session, map: map)
        scroll.documentView = canvas
        scroll.zoomChanged = { [weak session] value in session?.zoom = value }
        return scroll
    }

    func updateNSView(_ scroll: MapScrollView, context: Context) {
        guard let canvas = scroll.documentView as? MapCanvasView else { return }
        canvas.update(map: map)
        // Defer observation writes until SwiftUI has finished its update pass.
        if canvas.lastRequest != session.viewportRequest {
            canvas.lastRequest = session.viewportRequest
            let action = session.viewportAction
            DispatchQueue.main.async { [weak canvas] in canvas?.navigate(action) }
        }
        if let id = session.editingRequest {
            DispatchQueue.main.async { [weak canvas, weak session] in
                guard session?.editingRequest == id else { return }
                canvas?.beginEditing(id)
                session?.editingRequest = nil
            }
        }
        canvas.needsDisplay = true
    }
}

@MainActor
final class MapScrollView: NSScrollView {
    var zoomChanged: ((CGFloat) -> Void)?
    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        zoomChanged?(magnification)
    }
}
