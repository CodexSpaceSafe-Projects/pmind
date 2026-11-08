import AppKit
import SwiftUI
import OSLog

@main
struct PMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("pmind", id: HomeView.windowID) {
            HomeView()
        }
        .defaultSize(width: 880, height: 540)
        .windowResizability(.contentMinSize)

        DocumentGroup(newDocument: MindMapFile()) { file in
            EditorView(file: file.$document)
        }
        .defaultSize(width: 1180, height: 780)
        .commands { EditorCommands() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger(subsystem: "app.pmind.mac", category: "Lifecycle").info("Application launched")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
