import AppKit
import GhosttyClaudeBarCore

// Debug path: print the collected rows and exit (no GUI). Handy for verifying
// the data layer against the real ~/.claude without launching the menu bar.
if CommandLine.arguments.contains("--print") {
    let rows = Collector.collect()
    for r in rows {
        let dot: String
        switch r.state {
        case .working: dot = "🔴"
        case .needsReply: dot = "🟠"
        case .idle: dot = "🟡"
        case .safeToClose: dot = "🟢"
        case .other: dot = "⚪"
        }
        let term = r.terminalID.map { String($0.prefix(8)) } ?? "—"
        print("\(dot) [\(term)] \(r.menuTitle) — \(r.reason ?? "")")
    }
    print("— \(rows.count) row(s)")
    exit(0)
}

// Menu-bar agent app. `.accessory` keeps it out of the Dock and the app
// switcher even when launched via `swift run` (no bundle / Info.plist needed
// for dev — the packaged .app sets LSUIElement in Phase 5).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
