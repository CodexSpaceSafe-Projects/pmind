import SwiftUI
import MindMapCore

struct OutlineSidebar: View {
    @ObservedObject var session: EditorSession
    let root: Topic

    var body: some View {
        VStack(spacing: 0) {
            TextField("搜索主题与备注", text: $session.query)
                .textFieldStyle(.roundedBorder).padding(12)
                .onSubmit { if let id = session.matches.first { session.select(id, reveal: true) } }
            if session.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                List(selection: Binding<UUID?>(get: { session.selection }, set: {
                    if let id = $0 { session.select(id, reveal: true) }
                })) { OutlineRow(topic: root, session: session) }
                    .listStyle(.sidebar)
            } else {
                List(selection: Binding<UUID?>(get: { session.selection }, set: {
                    if let id = $0 { session.select(id, reveal: true) }
                })) {
                    ForEach(session.matches, id: \.self) { id in
                        Text(root.topic(id)?.title.isEmpty == false ? root.topic(id)!.title : "无标题")
                            .lineLimit(1).tag(id)
                    }
                }.listStyle(.sidebar)
                if session.matches.isEmpty { Text("没有匹配的主题").foregroundStyle(.secondary).padding() }
            }
        }
        .navigationTitle("大纲")
    }
}

private struct OutlineRow: View {
    let topic: Topic
    @ObservedObject var session: EditorSession
    var body: some View {
        if topic.children.isEmpty {
            label.tag(topic.id)
        } else {
            DisclosureGroup(isExpanded: Binding(get: { !topic.isCollapsed }, set: { expanded in
                if expanded == topic.isCollapsed { session.perform(.toggleFold(topic.id), label: "折叠或展开") }
            })) {
                ForEach(topic.children) { child in OutlineRow(topic: child, session: session) }
            } label: { label }.tag(topic.id)
        }
    }
    private var label: some View {
        Text(topic.title.isEmpty ? "无标题" : topic.title).lineLimit(1)
            .contextMenu {
                Button("添加子主题") { session.select(topic.id); session.addChild() }
                Button("编辑标题") { session.select(topic.id); session.edit() }
                if topic.id != session.map.root.id {
                    Button("删除主题") { session.perform(.delete(topic.id), label: "删除主题") }
                }
            }
    }
}
