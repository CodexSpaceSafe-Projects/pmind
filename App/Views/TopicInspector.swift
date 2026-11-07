import SwiftUI
import MindMapCore

struct TopicInspector: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        Form {
            if let topic = session.selectedTopic {
                Section("主题") {
                    TextField("标题", text: Binding(get: { session.selectedTopic?.title ?? "" }, set: {
                        session.perform(.rename(topic.id, $0), label: "编辑标题")
                    }), axis: .vertical).lineLimit(1...6)
                }
                Section("备注") {
                    TextEditor(text: Binding(get: { session.selectedTopic?.notes ?? "" }, set: {
                        session.perform(.notes(topic.id, $0), label: "编辑备注")
                    })).frame(minHeight: 180).font(.body).accessibilityLabel("主题备注")
                }
                if topic.id != session.map.root.id {
                    Section("分支颜色") {
                        Picker("颜色", selection: Binding<BranchColor?>(get: { topic.color }, set: {
                            session.perform(.color(topic.id, $0), label: "更改颜色")
                        })) {
                            Text("跟随分支").tag(Optional<BranchColor>.none)
                            ForEach(BranchColor.allCases, id: \.self) { color in
                                Text(color.title).tag(Optional(color))
                            }
                        }
                    }
                }
            }
        }.formStyle(.grouped)
    }
}
