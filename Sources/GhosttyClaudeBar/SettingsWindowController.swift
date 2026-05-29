import AppKit
import SwiftUI

/// Hosts `SettingsView` in a small fixed-size panel.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let monitor: SessionMonitor

    init(monitor: SessionMonitor) {
        self.monitor = monitor
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(monitor: monitor))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
