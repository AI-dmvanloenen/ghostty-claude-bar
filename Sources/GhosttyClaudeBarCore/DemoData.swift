import Foundation

/// Stub rows so the UI pipeline is exercised end-to-end before the real data
/// layer lands (Phase 1). Mirrors a real screenshot for a familiar feel.
public enum DemoData {
    public static func demoRows() -> [TabRow] {
        [
            TabRow(id: "1", title: "Analyze Mopo codebase for technical debt",
                   cwd: "~/GitHub/mobile-power", ageText: "4m",
                   state: .working, terminalID: "demo-1"),
            TabRow(id: "2", title: "Filter ai_mopo_cost_lot module todos",
                   cwd: "~/GitHub/mobile-power", ageText: "12m",
                   state: .needsReply, terminalID: "demo-2"),
            TabRow(id: "3", title: "Check if BOM revision touches lots/serials",
                   cwd: "~/GitHub/AdvanceInsight", ageText: "1h",
                   state: .idle, terminalID: "demo-3"),
            TabRow(id: "4", title: "Investigate Odoo 18 bug in China VAT flow",
                   cwd: "~/GitHub/AdvanceInsight", ageText: "3h",
                   state: .safeToClose, terminalID: "demo-4"),
            TabRow(id: "5", title: "Claude Code",
                   cwd: "~", ageText: nil,
                   state: .other, terminalID: "demo-5"),
        ]
    }
}
