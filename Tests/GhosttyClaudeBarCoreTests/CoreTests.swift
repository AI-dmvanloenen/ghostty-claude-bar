import Testing
import Foundation
@testable import GhosttyClaudeBarCore

@Test("demo rows cover every state")
func demoRowsCoverAllStates() {
    let rows = DemoData.demoRows()
    let states = Set(rows.map(\.state))
    #expect(states == Set(SessionState.allCases))
}

@Test("menuTitle appends age when present")
func menuTitleIncludesAge() {
    let row = TabRow(id: "x", title: "Do a thing", ageText: "2h", state: .idle)
    #expect(row.menuTitle.contains("2h"))
    #expect(row.menuTitle.hasPrefix("Do a thing"))
}

@Test("menuTitle omits age when absent")
func menuTitleNoAge() {
    let row = TabRow(id: "x", title: "Bare", state: .other)
    #expect(row.menuTitle == "Bare")
}

// MARK: - Ported logic

@Test("encodeCwd maps the dot too (the phantom-orphan fix)")
func encodeCwdDot() {
    // The trailing '.' rule is the one that bit the Python tool.
    #expect(Paths.encodeCwd("/Users/d/.claude/skills") == "-Users-d--claude-skills")
    #expect(Paths.encodeCwd("/a b/c_d&e") == "-a-b-c-d-e")
}

@Test("titleKeywords strips glyphs, stopwords, and short tokens")
func titleKeywords() {
    let kw = TextAnalysis.titleKeywords("✳ Analyze Mopo codebase for technical debt")
    #expect(kw == ["analyze", "mopo", "codebase", "technical", "debt"]) // "for" dropped
}

@Test("fmtAge picks the right unit")
func fmtAge() {
    #expect(Recommender.fmtAge(0.5) == "30m")
    #expect(Recommender.fmtAge(2.0) == "2.0h")
    #expect(Recommender.fmtAge(48.0) == "2.0d")
}

private func session(status: String?, ageHours: Double, sessionId: String = "") -> Session {
    let now = Date().timeIntervalSince1970
    let updatedMs = (now - ageHours * 3600) * 1000
    return Session(pid: 1, sessionId: sessionId, cwd: "/tmp/x",
                   status: status, startedAt: updatedMs, updatedAt: updatedMs)
}

@Test("busy status always wins")
func busyWins() {
    let v = Recommender.recommend(session: session(status: "busy", ageHours: 100),
                                  lastText: "done.", now: Date())
    #expect(v.state == .working)
}

@Test("a trailing question means it needs a reply")
func questionNeedsReply() {
    let v = Recommender.recommend(session: session(status: nil, ageHours: 1),
                                  lastText: "Which option do you prefer?", now: Date())
    #expect(v.state == .needsReply)
}

@Test("long-idle non-question session is safe to close")
func staleIsSafe() {
    let v = Recommender.recommend(session: session(status: nil, ageHours: 100),
                                  lastText: "still chugging along", now: Date())
    #expect(v.state == .safeToClose)
}

@Test("heuristic state classifies obvious cases")
func heuristic() {
    #expect(Recommender.heuristicState(lastText: "Which one do you want?") == "WAITING")
    #expect(Recommender.heuristicState(lastText: "All set, summary: done.") == "DONE")
    #expect(Recommender.heuristicState(lastText: "Now editing the file") == "ACTIVE")
    #expect(Recommender.heuristicState(lastText: nil) == "ACTIVE")
}

@Test("a fresh WAITING verdict overrides busy (blocked on user mid-turn)")
func waitingOverridesBusy() {
    let sid = "gcb-unittest-busy-\(getpid())"
    defer { try? FileManager.default.removeItem(atPath: VerdictStore.path(for: sid)) }

    let now = Date()
    // busy session, last activity 10s ago
    let s = Session(pid: 1, sessionId: sid, cwd: "/tmp/x", status: "busy",
                    startedAt: (now.timeIntervalSince1970 - 10) * 1000,
                    updatedAt: (now.timeIntervalSince1970 - 10) * 1000)

    // fresh notification verdict (now) → should override busy
    VerdictStore.write(sessionId: sid, state: "WAITING", ts: now.timeIntervalSince1970)
    #expect(Recommender.recommend(session: s, lastText: nil, now: now).state == .needsReply)

    // stale verdict (2 min ago) → busy wins again
    VerdictStore.write(sessionId: sid, state: "WAITING", ts: now.timeIntervalSince1970 - 120)
    #expect(Recommender.recommend(session: s, lastText: nil, now: now).state == .working)
}
