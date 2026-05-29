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
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(red: 0x0E / 255, green: 0x10 / 255, blue: 0x14 / 255, alpha: 1)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
