import AppKit
import GhosttyClaudeBarCore

/// Owns the `NSStatusItem` and builds its dropdown menu from `[TabRow]`.
///
/// Mirrors the proven SwiftBar UX: one line per Ghostty window, rows pre-sorted
/// working → needs-reply → idle → safe-to-close → other so colors cluster,
/// cwd in the tooltip, a single separator before the footer actions.
///
/// Refresh model (P3): the menu is rebuilt **synchronously on open** via
/// `NSMenuDelegate.menuNeedsUpdate` so it's always current. A 30s timer and an
/// FSEvents watcher on `~/.claude/sessions/` keep the menu-bar **icon** (count +
/// glyph) live in the background while the menu is closed.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let renderer = IconRenderer()
    private let menu = NSMenu()

    private var timer: Timer?
    private var watcher: FSEventsWatcher?

    private static let refreshInterval: TimeInterval = 30

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        if let button = statusItem.button {
            button.image = renderer.statusBarImage(needsReply: false)
            button.imagePosition = .imageLeading
        }

        refreshIcon()        // initial async icon fill
        startBackgroundRefresh()
    }

    // MARK: - Background icon refresh (menu closed)

    private func startBackgroundRefresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIcon() }
        }
        self.timer = timer

        let watcher = FSEventsWatcher(path: Paths.sessionsDir) { [weak self] in
            MainActor.assumeIsolated { self?.refreshIcon() }
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Recompute rows off-main and update only the menu-bar button (count + glyph).
    /// Cheap enough to run on every FSEvents tick; never blocks the menu.
    private func refreshIcon() {
        Task.detached(priority: .utility) {
            let rows = Collector.collect()
            await MainActor.run { self.applyIcon(rows) }
        }
    }

    private func applyIcon(_ rows: [TabRow]) {
        let needsReply = rows.contains { $0.state == .needsReply }
        guard let button = statusItem.button else { return }
        button.image = renderer.statusBarImage(needsReply: needsReply)
        button.imagePosition = .imageLeading
        button.title = " \(rows.count)"
        if ProcessInfo.processInfo.environment["GCB_DEBUG"] != nil {
            NSLog("[ghostty-claude-bar] refresh → \(rows.count) rows, needsReply=\(needsReply)")
        }
    }

    // MARK: - NSMenuDelegate (fresh-on-open)

    /// Called right before the menu is shown — collect synchronously so the
    /// dropdown always reflects the current instant. AppleScript + file reads are
    /// ~100ms; a brief, one-shot cost only when you actually open the menu.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let rows = Collector.collect()
        populate(menu, with: rows)
        applyIcon(rows)
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
            item.isEnabled = row.terminalID != nil // orphan sessions can't be focused
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let report = NSMenuItem(title: "Open full report", action: #selector(openReport), keyEquivalent: "")
        report.target = self
        menu.addItem(report)

        let quit = NSMenuItem(title: "Quit ghostty-claude-bar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func focusRow(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String, !uuid.isEmpty else { return }
        Task.detached { GhosttyClient.focus(terminalID: uuid) }
    }

    @objc private func refresh() {
        refreshIcon()
    }

    @objc private func openReport() {
        // Phase 4: render the HTML report and open it.
        NSLog("[ghostty-claude-bar] open full report (Phase 4)")
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
