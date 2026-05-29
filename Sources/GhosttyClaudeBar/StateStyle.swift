import SwiftUI
import GhosttyClaudeBarCore

/// Visual vocabulary for each session state — one place so the menu dots, the
/// window accents, and the section headers never drift apart.
struct StateStyle {
    let color: Color
    let label: String
    let symbol: String

    /// Whether this state is "live" (animate its indicator).
    var isLive: Bool

    static func of(_ state: SessionState) -> StateStyle {
        switch state {
        case .working:     StateStyle(color: Color(hex: 0xFF6B66), label: "Working",       symbol: "bolt.fill",             isLive: true)
        case .needsReply:  StateStyle(color: Color(hex: 0xF7B25C), label: "Needs reply",   symbol: "bubble.left.fill",      isLive: false)
        case .idle:        StateStyle(color: Color(hex: 0xE7D673), label: "Idle",          symbol: "pause.fill",            isLive: false)
        case .safeToClose: StateStyle(color: Color(hex: 0x5FD08A), label: "Safe to close", symbol: "checkmark.circle.fill", isLive: false)
        case .other:       StateStyle(color: Color(hex: 0x6E7886), label: "Other",         symbol: "macwindow",             isLive: false)
        }
    }

    /// The accent for the window's ambient glow: the most urgent active state.
    static func dominantColor(for states: [SessionState]) -> Color {
        for state in SessionState.allCases where states.contains(state) {
            return StateStyle.of(state).color
        }
        return Color(hex: 0x2A3140)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
