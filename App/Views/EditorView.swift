import SwiftUI
import MindMapCore

struct EditorView: View {
    @Binding private var file: MindMapFile
    @StateObject private var session: EditorSession
    @Environment(\.undoManager) private var undoManager
    @State private var inspectorVisible = false
    @State private var columns: NavigationSplitViewVisibility = .all

    init(file: Binding<MindMapFile>) {
        _file = file; _session = StateObject(wrappedValue: EditorSession(file: file))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            OutlineSidebar(session: session, root: file.map.root)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } detail: {
            VStack(spacing: 0) {
                MapCanvas(session: session, map: file.map)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                HStack(spacing: 14) {
                    Spacer()
                    Text("\(file.map.root.count) 个主题").foregroundStyle(.secondary)
                    Button { session.request(.zoomOut) } label: { Image(systemName: "minus") }.help("缩小")
                    Text(session.zoom, format: .percent.precision(.fractionLength(0))).monospacedDigit().frame(width: 44)
                    Button { session.request(.zoomIn) } label: { Image(systemName: "plus") }.help("放大")
                    Button { session.request(.center) } label: { Image(systemName: "scope") }.help("定位中心主题")
                }
                .buttonStyle(.borderless).font(.system(size: 11)).padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .inspector(isPresented: $inspectorVisible) {
            TopicInspector(session: session).inspectorColumnWidth(min: 220, ideal: 260, max: 340)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { session.addSibling() } label: { Label("同级主题", systemImage: "arrow.turn.down.right") }
                    .disabled(!session.canDelete).help("添加同级主题 · Return")
                Button { session.addChild() } label: { Label("子主题", systemImage: "arrow.triangle.branch") }
                    .help("添加子主题 · Tab")
                Button { session.fold() } label: { Label("折叠 / 展开", systemImage: "rectangle.compress.vertical") }
                    .disabled(session.selectedTopic?.children.isEmpty != false)
                Button { session.delete() } label: { Label("删除主题", systemImage: "trash") }
                    .disabled(!session.canDelete)
            }
            ToolbarItem {
                Picker("布局", selection: Binding(get: { file.map.layout }, set: {
                    session.perform(.layout($0), label: "切换布局"); session.request(.fit)
                })) {
                    Text("思维导图").tag(MapLayout.mindMap)
                    Text("向右逻辑图").tag(MapLayout.rightTree)
                }.frame(width: 132)
            }
            ToolbarItem {
                Button { session.request(.fit) } label: { Label("适应窗口", systemImage: "arrow.up.left.and.arrow.down.right") }
            }
            ToolbarItem {
                Button { inspectorVisible.toggle() } label: { Label("主题详情", systemImage: "sidebar.right") }
            }
        }
        .focusedSceneValue(\.editorSession, session)
        .onAppear { session.undoManager = undoManager }
        .alert("无法完成操作", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("好") { session.error = nil }
        } message: { Text(session.error ?? "") }
        .frame(minWidth: 820, minHeight: 520)
    }
}
