import AppKit

/// Menu-bar (`.accessory`) apps are excluded from Cmd-Tab and the Dock. But when
/// a real window is open the user expects to Cmd-Tab to it. So we flip to
/// `.regular` while any of our windows is visible, and back to `.accessory` when
/// the last one closes — Dock icon + Cmd-Tab appear only when there's a window
/// to switch to.
@MainActor
enum WindowActivation {
    private static let tracked = NSHashTable<NSWindow>.weakObjects()

    /// Show a window and make the app Cmd-Tab-able.
    static func present(_ window: NSWindow) {
        tracked.add(window)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Call from `windowWillClose`. Reverts to menu-bar-only once no tracked
    /// window remains visible (deferred so the closing window reads as hidden).
    static func windowWillClose() {
        DispatchQueue.main.async {
            let anyVisible = tracked.allObjects.contains { $0.isVisible }
            NSApp.setActivationPolicy(anyVisible ? .regular : .accessory)
        }
    }
}
