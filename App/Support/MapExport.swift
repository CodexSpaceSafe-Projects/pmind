import AppKit
import UniformTypeIdentifiers
import MindMapCore

@MainActor
enum MapExport {
    enum Format { case markdown, png, pdf }
    static func save(_ session: EditorSession, format: Format) {
        // Commit any field-editor changes before taking the export snapshot.
        guard session.commitEditing() else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        let panel = NSSavePanel()
        let ext: String
        switch format {
        case .markdown: ext = "md"; panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        case .png: ext = "png"; panel.allowedContentTypes = [.png]
        case .pdf: ext = "pdf"; panel.allowedContentTypes = [.pdf]
        }
        let title = session.map.root.title.components(separatedBy: .newlines).first ?? "思维导图"
        panel.nameFieldStringValue = (title.isEmpty ? "思维导图" : title.replacingOccurrences(of: "/", with: "-")) + "." + ext
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data: Data
            if case .markdown = format {
                data = Data(MarkdownCodec.encode(session.map).utf8)
            } else {
                let geometry = MapLayoutEngine.layout(session.map, measure: MapRenderer.measure)
                let view = ExportCanvas(map: session.map, geometry: geometry)
                if case .pdf = format { data = view.dataWithPDF(inside: view.bounds) }
                else {
                    let width = Int(ceil(geometry.size.width * 2)), height = Int(ceil(geometry.size.height * 2))
                    guard width <= 16384, height <= 16384, Double(width) * Double(height) <= 64_000_000,
                          let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
                        session.error = "导图过大，无法导出 PNG。请使用 PDF 或折叠部分分支后重试。"; return
                    }
                    bitmap.size = geometry.size
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = context
                    let cg = context.cgContext
                    cg.scaleBy(x: 2, y: 2); cg.translateBy(x: 0, y: geometry.size.height); cg.scaleBy(x: 1, y: -1)
                    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
                    MapRenderer.draw(map: session.map, geometry: geometry)
                    NSGraphicsContext.restoreGraphicsState()
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw MapError.invalidFormat }
                    data = png
                }
            }
            try data.write(to: url, options: .atomic)
        } catch { session.error = error.localizedDescription }
    }
}

@MainActor
private final class ExportCanvas: NSView {
    let map: MindMap
    let geometry: MapGeometry
    override var isFlipped: Bool { true }
    init(map: MindMap, geometry: MapGeometry) {
        self.map = map; self.geometry = geometry
        super.init(frame: CGRect(origin: .zero, size: geometry.size))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ dirtyRect: NSRect) { MapRenderer.draw(map: map, geometry: geometry) }
}
