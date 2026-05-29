import Foundation

/// Fuzzy window↔session matching. There is NO direct PID↔window binding in
/// Ghostty, so we score each tab's title keywords against each session's
/// transcript fingerprint and pick a greedy 1-to-1 assignment. This is the
/// weakest link (identical titles in the same cwd can mis-assign) — kept faithful
/// to the Python tool, including the leftover-pairing second pass.
enum Matcher {
    /// Greedy best-score assignment. Returns sessionPid → matched tab.
    static func matchWindows(tabs: [GhosttyTab], sessions: [Session]) -> [Int: GhosttyTab] {
        guard !tabs.isEmpty, !sessions.isEmpty else { return [:] }

        let fingerprints = Dictionary(uniqueKeysWithValues: sessions.map {
            ($0.pid, TextAnalysis.fingerprint(jsonlPath: $0.jsonlPath, cwd: $0.cwd))
        })

        // (score, tabIndex, pid), only positive scores.
        var pairs: [(score: Int, tabIndex: Int, pid: Int)] = []
        for (ti, tab) in tabs.enumerated() {
            let keywords = TextAnalysis.titleKeywords(tab.title)
            for s in sessions {
                let fp = fingerprints[s.pid] ?? ""
                let score = keywords.reduce(0) { $0 + (fp.contains($1) ? 1 : 0) }
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
    }
}
