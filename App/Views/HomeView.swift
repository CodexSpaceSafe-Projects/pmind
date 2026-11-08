import AppKit
import SwiftUI

struct HomeView: View {
    static let windowID = "pmind.home"
    @Environment(\.newDocument) private var newDocument
    @Environment(\.openDocument) private var openDocument
    @State private var recentDocuments: [URL] = []
    @State private var error: String?
    @State private var isOpeningFile = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 48, weight: .light)).foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("pmind").font(.system(size: 34, weight: .semibold))
                Text("从一个想法开始。").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Button {
                    newDocument(MindMapFile())
                } label: {
                    Label("新建导图", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .help("新建一份空白思维导图（⌘N）")
                Button {
                    isOpeningFile = true
                } label: {
                    Label("打开文件…", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered).controlSize(.large)
                .help("打开 pmind 或 Markdown 文件（⌘O）")
                Text("支持 .pmind、Markdown 文件")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(36).frame(width: 290)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                Text("最近打开").font(.title2.weight(.semibold))
                if recentDocuments.isEmpty {
                    ContentUnavailableView("还没有最近打开的导图", systemImage: "doc.text",
                                           description: Text("新建导图，或打开已有文件。"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(recentDocuments, id: \.self) { url in
                                Button { openRecentDocument(url) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(url.lastPathComponent).font(.headline).lineLimit(1)
                                            Text(url.deletingLastPathComponent().lastPathComponent)
                                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(12).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).help(url.path)
                                .accessibilityLabel("打开 \(url.lastPathComponent)")
                            }
                        }
                    }
                }
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 480)
        .onAppear(perform: refreshRecentDocuments)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshRecentDocuments()
        }
        .fileImporter(isPresented: $isOpeningFile, allowedContentTypes: MindMapFile.readableContentTypes) { result in
            switch result {
            case .success(let url): openRecentDocument(url)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .alert("无法打开文件", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func refreshRecentDocuments() {
        recentDocuments = Array(NSDocumentController.shared.recentDocumentURLs.prefix(8))
    }

    private func openRecentDocument(_ url: URL) {
        Task { @MainActor in
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                try await openDocument(at: url)
                refreshRecentDocuments()
            } catch { self.error = error.localizedDescription }
        }
    }
}
