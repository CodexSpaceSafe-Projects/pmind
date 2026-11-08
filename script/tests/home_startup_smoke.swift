import AppKit
import CoreGraphics
import Foundation

@main
struct HomeStartupSmoke {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else { throw failure("Expected the app bundle path") }
            let url = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = true
            configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"]
            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            defer { app.terminate() }

            var windows: [[String: Any]] = []
            for _ in 0..<100 {
                windows = visibleWindows(for: app.processIdentifier)
                if !windows.isEmpty { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            // Allow any automatic document dialog to appear before checking the final state.
            try await Task.sleep(nanoseconds: 1_000_000_000)
            windows = visibleWindows(for: app.processIdentifier)
            let titles = windows.map { $0[kCGWindowName as String] as? String ?? "<title unavailable>" }
            guard windows.count == 1, titles == ["pmind"] else {
                throw failure("Expected only the pmind home window, found: \(titles)")
            }
            print("Startup smoke passed: only the pmind home window is visible; no document picker.")
        } catch {
            FileHandle.standardError.write(Data("Startup smoke failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func visibleWindows(for pid: pid_t) -> [[String: Any]] {
        let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return all.filter { window in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { return false }
            return width > 400 && height > 300
        }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "pmind.StartupSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
