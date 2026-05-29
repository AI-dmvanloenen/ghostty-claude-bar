import Foundation

/// Orchestrates the whole survey: load live Claude sessions, enumerate Ghostty
/// tabs, and emit one row PER SESSION (session-centric). The Ghostty window is
/// matched best-effort and used only for the title label + focus target — never
/// for status — so an imperfect match can't show the wrong state. Windows with
/// no live session are not shown.
public enum Collector {
    /// Collect the current rows, sorted for display. Safe to call off the main
    /// thread (pure Foundation + subprocesses).
    public static func collect(now: Date = Date()) -> [TabRow] {
        var sessions = SessionStore.load()
        for i in sessions.indices {
            sessions[i].jsonlPath = Paths.transcriptPath(
                sessionId: sessions[i].sessionId, cwd: sessions[i].cwd
            )
        }
        let tabs = GhosttyClient.tabs()

        // Scan each transcript via the cache — only changed files are re-read.
        var scans: [Int: TranscriptScan] = [:]
        for s in sessions {
            scans[s.pid] = TranscriptCache.shared.scan(path: s.jsonlPath, cwd: s.cwd)
        }
        TranscriptCache.shared.prune(livePaths: Set(sessions.compactMap(\.jsonlPath)))
        let fingerprints = scans.mapValues(\.fingerprint)

        // Best-effort window per session, used ONLY for the title label + the
        // focus target. Status/cwd/tokens come from the session itself, so a
        // wrong or missing window match can never corrupt what matters.
        let windowForPid = Matcher.matchWindows(tabs: tabs, sessions: sessions, fingerprints: fingerprints)
        var sessForTerm: [String: Int] = [:]
        for (pid, tab) in windowForPid { sessForTerm[tab.terminalID] = pid }
        Matcher.pairLeftovers(tabs: tabs, sessions: sessions, sessForTerm: &sessForTerm)

        var tabByTerm: [String: GhosttyTab] = [:]
        for t in tabs { tabByTerm[t.terminalID] = t }
        var tabForPid: [Int: GhosttyTab] = [:]
        for (term, pid) in sessForTerm { if let t = tabByTerm[term] { tabForPid[pid] = t } }

        var tabsPerWindow: [Int: Int] = [:]
        for t in tabs { tabsPerWindow[t.window, default: 0] += 1 }
        func windowLabel(_ t: GhosttyTab) -> String {
            let multi = (tabsPerWindow[t.window] ?? 0) > 1
            return "W\(t.window)" + (multi ? "·T\(t.tab)" : "")
        }

        // SESSION-CENTRIC: exactly one row per live Claude session. Windows with
        // no live session are intentionally NOT shown — this tool is about
        // sessions that need attention, and surfacing bare / ended-session
        // terminals only produced confusing "ghost" rows. No session is ever
        // dropped or duplicated, and status is always correct.
        let rows = sessions.map { session -> TabRow in
            let tab = tabForPid[session.pid]
            return row(from: session, scan: scans[session.pid], tab: tab,
                       label: tab.map(windowLabel) ?? "—", now: now)
        }
        return sort(rows)
    }

    private static func row(from session: Session, scan: TranscriptScan?, tab: GhosttyTab?, label: String, now: Date) -> TabRow {
        let lastText = scan?.lastAssistantText
        let verdict = Recommender.recommend(session: session, lastText: lastText, now: now)
        let ageH = session.ageHours(now: now)
        let usage = scan?.usage ?? Usage.Summary(tokens: 0, cost: nil, unknown: false)

        let title: String
        if let tab {
            title = TextAnalysis.stripLeadingGlyphs(tab.title)
        } else {
            let base = (session.cwd as NSString).lastPathComponent
            title = base.isEmpty ? "session" : base
        }

        let preview = lastText.map { String($0.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespaces) }

        return TabRow(
            id: "pid-\(session.pid)",
            title: title.isEmpty ? "session" : title,
            cwd: Paths.collapseHome(session.cwd),
            ageText: session.updatedAt != 0 || session.startedAt != 0 ? Recommender.fmtAge(ageH) : nil,
            state: verdict.state,
            reason: verdict.reason,
            terminalID: tab?.terminalID,
            windowLabel: label,
            pid: session.pid,
            status: session.status,
            tokens: usage.tokens,
            tokensText: usage.tokens > 0 ? Usage.fmtTokens(usage.tokens) : nil,
            costText: usage.tokens > 0 ? Usage.fmtCost(usage) : nil,
            costUSD: usage.cost,
            lastMessage: (preview?.isEmpty ?? true) ? nil : preview
        )
    }

    /// Sort: working → needs-reply → idle → safe-to-close → other, orphans last.
    private static func sort(_ rows: [TabRow]) -> [TabRow] {
        let order = SessionState.allCases
        return rows.sorted { a, b in
            let oa = order.firstIndex(of: a.state) ?? 0
            let ob = order.firstIndex(of: b.state) ?? 0
            if oa != ob { return oa < ob }
            // orphan rows (no terminalID) after windowed ones
            let orphanA = a.terminalID == nil
            let orphanB = b.terminalID == nil
            if orphanA != orphanB { return !orphanA }
            return a.id < b.id
        }
    }
}
