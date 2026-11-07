import AppKit
import SwiftUI

struct EditorSessionKey: FocusedValueKey { typealias Value = EditorSession }
extension FocusedValues {
    var editorSession: EditorSession? {
        get { self[EditorSessionKey.self] }
        set { self[EditorSessionKey.self] = newValue }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorSession) private var session
    var body: some Commands {
        CommandMenu("主题") {
            Button("添加子主题") { session?.addChild() }.keyboardShortcut(.return, modifiers: .command)
            Button("添加同级主题") { session?.addSibling() }.keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(session?.canDelete != true)
            Divider()
            Button("编辑标题") { session?.edit() }.keyboardShortcut("e", modifiers: .command)
            Button("折叠 / 展开") { session?.fold() }.keyboardShortcut(".", modifiers: .command)
            Button("删除主题") { session?.delete() }.disabled(session?.canDelete != true)
            Divider()
            Button("复制主题") { session?.copyTopic() }
            Button("粘贴为子主题") { session?.pasteTopic() }
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存") {
                guard let session, session.commitEditing() else { return }
                NSApp.keyWindow?.makeFirstResponder(nil)
                NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
            }.keyboardShortcut("s").disabled(session == nil)
            Button("另存为…") {
                guard let session, session.commitEditing() else { return }
                NSApp.keyWindow?.makeFirstResponder(nil)
                NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
            }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(session == nil)
        }
        CommandGroup(after: .toolbar) {
            Button("放大") { session?.request(.zoomIn) }.keyboardShortcut("+", modifiers: .command)
            Button("缩小") { session?.request(.zoomOut) }.keyboardShortcut("-", modifiers: .command)
            Button("适应窗口") { session?.request(.fit) }.keyboardShortcut("0", modifiers: .command)
            Button("定位中心主题") { session?.request(.center) }.keyboardShortcut("1", modifiers: .command)
        }
        CommandGroup(after: .saveItem) {
            Menu("导出") {
                Button("Markdown…") { if let session { MapExport.save(session, format: .markdown) } }
                Button("PNG 图片…") { if let session { MapExport.save(session, format: .png) } }
                Button("PDF…") { if let session { MapExport.save(session, format: .pdf) } }
            }.disabled(session == nil)
        }
    }
}
