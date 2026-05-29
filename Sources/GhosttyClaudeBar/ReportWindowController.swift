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
            window.setContentSize(NSSize(width: 660, height: 560))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden            // our header is the title
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(red: 0x0E / 255, green: 0x10 / 255, blue: 0x14 / 255, alpha: 1)
            window.center()
            self.window = window
        }
        // .accessory apps must explicitly activate to surface a window.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        monitor.refreshAsync()
    }
}
