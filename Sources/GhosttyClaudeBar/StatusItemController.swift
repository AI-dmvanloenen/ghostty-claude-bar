import AppKit
import GhosttyClaudeBarCore

/// Owns the `NSStatusItem` and builds its dropdown menu from `[TabRow]`.
///
/// Mirrors the proven SwiftBar UX: one line per Ghostty window, rows pre-sorted
/// working → needs-reply → idle → safe-to-close → other so colors cluster,
/// cwd in the tooltip, a single separator before the footer actions.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let renderer = IconRenderer()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuild()
    }

    /// Recompute everything from the current row set. Phase 0 uses demo data;
    /// Phase 1 swaps in the real collector, Phase 3 calls this on a timer +
    /// FSEvents + menuWillOpen.
    func rebuild() {
        let rows = DemoData.demoRows()
        let needsReply = rows.contains { $0.state == .needsReply }

        if let button = statusItem.button {
            button.image = renderer.statusBarImage(needsReply: needsReply)
            button.imagePosition = .imageLeading
            button.title = " \(rows.count)"
        }
        statusItem.menu = buildMenu(rows)
    }

    private func buildMenu(_ rows: [TabRow]) -> NSMenu {
        let menu = NSMenu()

        let order = SessionState.allCases
        let sorted = rows.sorted {
            (order.firstIndex(of: $0.state) ?? 0) < (order.firstIndex(of: $1.state) ?? 0)
        }

        if sorted.isEmpty {
            let empty = NSMenuItem(title: "No open Ghostty windows", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        for row in sorted {
            let item = NSMenuItem(title: row.menuTitle,
                                  action: #selector(focusRow(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.image = renderer.dotImage(for: row.state)
            item.toolTip = row.cwd
            item.representedObject = row.terminalID
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let report = NSMenuItem(title: "Open full report", action: #selector(openReport), keyEquivalent: "")
        report.target = self
        menu.addItem(report)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func focusRow(_ sender: NSMenuItem) {
        // Phase 2: `focus terminal whose id is "<uuid>"` via AppleScript.
        let uuid = sender.representedObject as? String ?? "nil"
        NSLog("[ghostty-claude-bar] focus row → terminal \(uuid)")
    }

    @objc private func refresh() {
        rebuild()
    }

    @objc private func openReport() {
        // Phase 4: render the HTML report and open it.
        NSLog("[ghostty-claude-bar] open full report (Phase 4)")
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
