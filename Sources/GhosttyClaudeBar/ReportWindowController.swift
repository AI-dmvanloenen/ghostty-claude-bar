import AppKit
import SwiftUI
import GhosttyClaudeBarCore

/// Hosts the SwiftUI `ReportView` in a real, reusable AppKit window. Created
/// lazily on first open; kept alive across closes (`isReleasedWhenClosed = false`).
@MainActor
final class ReportWindowController {
    private var window: NSWindow?
    private let monitor: SessionMonitor

    init(monitor: SessionMonitor) {
        self.monitor = monitor
    }

    func show() {
        if window == nil {
            let view = ReportView(monitor: monitor) { uuid in
                Task.detached { GhosttyClient.focus(terminalID: uuid) }
            }
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Claude Code Sessions"
            window.setContentSize(NSSize(width: 640, height: 540))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // .accessory apps must explicitly activate to surface a window.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        monitor.refreshAsync()
    }
}
