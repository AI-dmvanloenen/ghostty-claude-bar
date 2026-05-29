import Foundation

/// Fuzzy window↔session matching. There is NO direct PID↔window binding in
/// Ghostty, so we score each tab's title keywords against each session's
/// transcript fingerprint and pick a greedy 1-to-1 assignment. This is the
/// weakest link (identical titles in the same cwd can mis-assign) — kept faithful
/// to the Python tool, including the leftover-pairing second pass.
enum Matcher {
    /// Greedy best-score assignment. Returns sessionPid → matched tab.
    /// `fingerprints` are precomputed (one transcript read in the collector).
    static func matchWindows(
        tabs: [GhosttyTab],
        sessions: [Session],
        fingerprints: [Int: String]
    ) -> [Int: GhosttyTab] {
        guard !tabs.isEmpty, !sessions.isEmpty else { return [:] }

        // IDF weight per title keyword: a word found in only one session's
        // fingerprint ("mopo", "taste") is discriminative and should decide the
        // match; a word in many ("ghostty", "claude", "report") is near-useless.
        // Raw hit-counting let common words cross-assign sessions to the wrong
        // window and drop others to "no match" — IDF weighting fixes that.
        let n = Double(sessions.count)
        let allKeywords = Set(tabs.flatMap { TextAnalysis.titleKeywords($0.title) })
        var idf: [String: Double] = [:]
        for kw in allKeywords {
            let df = sessions.reduce(0) { $0 + ((fingerprints[$1.pid]?.contains(kw) == true) ? 1 : 0) }
            idf[kw] = df == 0 ? 0 : log(1.0 + n / Double(df))
        }

        // (score, tabIndex, pid), only positive scores.
        var pairs: [(score: Double, tabIndex: Int, pid: Int)] = []
        for (ti, tab) in tabs.enumerated() {
            let keywords = TextAnalysis.titleKeywords(tab.title)
            for s in sessions {
                let fp = fingerprints[s.pid] ?? ""
                let score = keywords.reduce(0.0) { $0 + (fp.contains($1) ? (idf[$1] ?? 0) : 0) }
                if score > 0 { pairs.append((score, ti, s.pid)) }
            }
        }

        pairs.sort { $0.score != $1.score ? $0.score > $1.score : $0.tabIndex < $1.tabIndex }

        var usedTabs = Set<Int>()
        var usedPids = Set<Int>()
        var out: [Int: GhosttyTab] = [:]
        for pair in pairs {
            if usedTabs.contains(pair.tabIndex) || usedPids.contains(pair.pid) { continue }
            out[pair.pid] = tabs[pair.tabIndex]
            usedTabs.insert(pair.tabIndex)
            usedPids.insert(pair.pid)
        }
        return out
    }

    private static let genericTitles: Set<String> = ["", "claude code", "claude"]

    /// Second pass: bind leftover tabs ↔ leftover sessions. A brand-new window
    /// keeps the default "Claude Code" title with an empty transcript (scores
    /// zero above), which would otherwise split into two rows. Round 1 matches by
    /// cwd-basename appearing in the title; round 2 gives a still-default-titled
    /// window the newest unmatched session. Path-titled shells stay unmatched.
    ///
    /// Mutates `sessForTerm` (terminalID → pid) in place.
    static func pairLeftovers(
        tabs: [GhosttyTab],
        sessions: [Session],
        sessForTerm: inout [String: Int]
    ) {
        let matchedPids = Set(sessForTerm.values)
        let leftoverTabs = tabs.filter { sessForTerm[$0.terminalID] == nil }
        let leftoverSessions = sessions.filter { !matchedPids.contains($0.pid) }
        guard !leftoverTabs.isEmpty, !leftoverSessions.isEmpty else { return }

        func cwdBase(_ s: Session) -> String {
            (s.cwd as NSString).lastPathComponent.lowercased()
        }
        func norm(_ t: GhosttyTab) -> String {
            TextAnalysis.stripLeadingGlyphs(t.title)
                .trimmingCharacters(in: .whitespaces).lowercased()
        }

        var used = Set<Int>()

        // Round 1: cwd basename appears in the window title.
        for t in leftoverTabs {
            let tl = norm(t)
            for s in leftoverSessions where !used.contains(s.pid) {
                let base = cwdBase(s)
                if !base.isEmpty, tl.contains(base) {
                    sessForTerm[t.terminalID] = s.pid
                    used.insert(s.pid)
                    break
                }
            }
        }

        // Round 2: a still-default-titled window → newest unmatched session.
        for t in leftoverTabs {
            if sessForTerm[t.terminalID] != nil { continue }
            guard genericTitles.contains(norm(t)) else { continue }
            let remaining = leftoverSessions.filter { !used.contains($0.pid) }
            guard let newest = remaining.max(by: { $0.startedAt < $1.startedAt }) else { break }
            sessForTerm[t.terminalID] = newest.pid
            used.insert(newest.pid)
        }

        // Round 3: process of elimination. Give any still-unmatched session a
        // still-unmatched window (in order) so its focus/close/rename actions
        // work. The label may be approximate, but status is session-driven so it
        // stays correct. With equal counts this is usually the right pairing.
        var freeSessions = leftoverSessions.filter { !used.contains($0.pid) }
        for t in leftoverTabs where sessForTerm[t.terminalID] == nil {
            guard !freeSessions.isEmpty else { break }
            sessForTerm[t.terminalID] = freeSessions.removeFirst().pid
        }
    }
}
