import Foundation

/// Orchestrates the whole survey: load sessions, enumerate Ghostty tabs, match
/// them, and emit one `TabRow` per window (tab-centric — every window shows),
/// with unmatched sessions appended so nothing is lost. This is the Swift port
/// of the Python `build_rows`.
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

        // pid → tab, then flip to terminalID → pid for tab-centric assembly.
        let windowForPid = Matcher.matchWindows(tabs: tabs, sessions: sessions, fingerprints: fingerprints)
        var sessForTerm: [String: Int] = [:]
        for (pid, tab) in windowForPid { sessForTerm[tab.terminalID] = pid }
        Matcher.pairLeftovers(tabs: tabs, sessions: sessions, sessForTerm: &sessForTerm)

        var sessionByPid: [Int: Session] = [:]
        for s in sessions { sessionByPid[s.pid] = s }

        var tabsPerWindow: [Int: Int] = [:]
        for t in tabs { tabsPerWindow[t.window, default: 0] += 1 }
        func windowLabel(_ t: GhosttyTab) -> String {
            let multi = (tabsPerWindow[t.window] ?? 0) > 1
            return "W\(t.window)" + (multi ? "·T\(t.tab)" : "")
        }

        var rows: [TabRow] = []
        var matchedPids = Set<Int>()

        for tab in tabs {
            if let pid = sessForTerm[tab.terminalID], let session = sessionByPid[pid] {
                matchedPids.insert(pid)
                rows.append(row(from: session, scan: scans[pid], tab: tab, label: windowLabel(tab), now: now))
            } else {
                // A Ghostty window with no tracked Claude session (plain shell).
                let stripped = TextAnalysis.stripLeadingGlyphs(tab.title)
                rows.append(TabRow(
                    id: "term-\(tab.terminalID)-\(tab.window)-\(tab.tab)",
                    title: stripped.isEmpty ? "Terminal" : stripped,
                    cwd: nil,
                    ageText: nil,
                    state: .other,
                    reason: "no Claude session",
                    terminalID: tab.terminalID,
                    windowLabel: windowLabel(tab)
                ))
            }
        }

        // Sessions that matched no tab — keep them (window "—").
        for session in sessions where !matchedPids.contains(session.pid) {
            rows.append(row(from: session, scan: scans[session.pid], tab: nil, label: "—", now: now))
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
