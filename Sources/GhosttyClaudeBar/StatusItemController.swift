import AppKit
import GhosttyClaudeBarCore

/// Owns the `NSStatusItem` and builds its dropdown from `SessionMonitor`.
///
/// The menu rebuilds synchronously on open (`menuNeedsUpdate`) so it's always
/// current; the icon repaints whenever the monitor refreshes (its `onUpdate`).
/// All refresh scheduling lives in the monitor, not here.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let renderer = IconRenderer()
    private let menu = NSMenu()
    private let monitor: SessionMonitor
    private let onOpenReport: () -> Void
    private let onOpenSettings: () -> Void

    init(monitor: SessionMonitor, onOpenReport: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.monitor = monitor
        self.onOpenReport = onOpenReport
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        if let button = statusItem.button {
            button.image = renderer.statusBarImage(needsReply: false)
            button.imagePosition = .imageLeading
        }

        monitor.onUpdate = { [weak self] m in self?.applyIcon(m) }
    }

    private func applyIcon(_ monitor: SessionMonitor) {
        guard let button = statusItem.button else { return }
        button.image = renderer.statusBarImage(needsReply: monitor.needsReply)
        button.imagePosition = .imageLeading
        button.title = " \(monitor.rows.count)"
    }

    // MARK: - NSMenuDelegate (fresh-on-open)

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Populate from cache so the menu opens INSTANTLY. The cache is kept fresh
        // by FSEvents + the timer, so it's current within ~1s of any change. Only
        // the very first open (cold cache) pays for a synchronous collect.
        let rows = monitor.rows.isEmpty ? monitor.refreshSync() : monitor.rows
        populate(menu, with: rows)
        monitor.refreshAsync() // refresh for the next open + the icon
    }

    private func populate(_ menu: NSMenu, with rows: [TabRow]) {
        menu.removeAllItems()

        if rows.isEmpty {
            let empty = NSMenuItem(title: "No open Ghostty windows", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        for row in rows {
            let item = NSMenuItem(title: row.menuTitle,
                                  action: #selector(focusRow(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.image = renderer.dotImage(for: row.state)
            item.toolTip = [row.cwd, row.reason].compactMap { $0 }.joined(separator: " — ")
            item.representedObject = row.terminalID
            item.isEnabled = row.terminalID != nil
            menu.addItem(item)
        }

        menu.addItem(.separator())

        addItem(to: menu, "Open", #selector(openReport), key: "o")
        addItem(to: menu, "Refresh", #selector(refresh), key: "r")
        addItem(to: menu, "Settings…", #selector(openSettings), key: ",")
        menu.addItem(.separator())
        addItem(to: menu, "Quit ghostty-claude-bar", #selector(quit), key: "q")
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func focusRow(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String, !uuid.isEmpty else { return }
        Task.detached { GhosttyClient.focus(terminalID: uuid) }
    }

    @objc private func refresh() { monitor.refreshAsync() }
    @objc private func openReport() { onOpenReport() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
