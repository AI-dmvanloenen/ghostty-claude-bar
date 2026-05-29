import Foundation
import GhosttyClaudeBarCore

/// Single source of truth for the current sessions. Owns the refresh triggers
/// (FSEvents on `~/.claude/sessions/` + a backstop timer) and publishes `[TabRow]`
/// so both the SwiftUI report window (`@ObservedObject`) and the AppKit menu-bar
/// icon (`onUpdate` callback) stay in sync from one collect.
@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var rows: [TabRow] = []
    @Published private(set) var lastUpdated: Date = .distantPast

    /// Called on the main actor after every refresh — used by the status item to
    /// repaint its icon without pulling in Combine.
    var onUpdate: ((SessionMonitor) -> Void)?

    private var timer: Timer?
    private var watcher: FSEventsWatcher?
    private(set) var interval: TimeInterval

    private lazy var judge = JudgeService { [weak self] in self?.refreshAsync() }

    // Coalesce bursts: while a collect runs, extra requests set `pending` and one
    // trailing collect runs after — so mid-turn FSEvents storms don't thrash.
    private var refreshing = false
    private var pending = false

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func start() {
        refreshAsync()
        installTimer()
        let watcher = FSEventsWatcher(path: Paths.sessionsDir) { [weak self] in
            MainActor.assumeIsolated { self?.refreshAsync() }
        }
        watcher.start()
        self.watcher = watcher
    }

    func setInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        installTimer()
    }

    private func installTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAsync() }
        }
    }

    /// Collect off-main, apply on main. Coalesced so overlapping requests don't
    /// stack up into redundant collects.
    func refreshAsync() {
        if refreshing { pending = true; return }
        refreshing = true
        Task.detached(priority: .utility) {
            let rows = Collector.collect()
            await MainActor.run {
                self.apply(rows)
                self.refreshing = false
                if self.pending {
                    self.pending = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refreshAsync() }
                }
            }
        }
    }

    /// Collect synchronously (for the menu's fresh-on-open path). ~100ms.
    @discardableResult
    func refreshSync() -> [TabRow] {
        let rows = Collector.collect()
        apply(rows)
        return rows
    }

    private func apply(_ rows: [TabRow]) {
        self.rows = rows
        self.lastUpdated = Date()
        onUpdate?(self)
        judge.scan() // refine any freshly-finished turns with Haiku
    }

    /// Rows grouped by state in display order.
    func grouped() -> [(state: SessionState, rows: [TabRow])] {
        SessionState.allCases.compactMap { state in
            let group = rows.filter { $0.state == state }
            return group.isEmpty ? nil : (state, group)
        }
    }

    var needsReply: Bool { rows.contains { $0.state == .needsReply } }
}
