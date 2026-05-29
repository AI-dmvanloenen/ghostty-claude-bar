import Testing
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
