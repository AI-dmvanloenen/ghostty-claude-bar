import SwiftUI
import GhosttyClaudeBarCore

/// Visual vocabulary for each session state — one place so the menu dots, the
/// window accents, and the section headers never drift apart.
struct StateStyle {
    let color: Color
    let label: String
    let symbol: String

    static func of(_ state: SessionState) -> StateStyle {
        switch state {
        case .working:     StateStyle(color: Color(hex: 0xE0726B), label: "Working",      symbol: "bolt.fill")
        case .needsReply:  StateStyle(color: Color(hex: 0xE0A458), label: "Needs reply",  symbol: "bubble.left.fill")
        case .idle:        StateStyle(color: Color(hex: 0xD4C46A), label: "Idle",         symbol: "pause.fill")
        case .safeToClose: StateStyle(color: Color(hex: 0x57C97D), label: "Safe to close", symbol: "checkmark.circle.fill")
        case .other:       StateStyle(color: Color.secondary,      label: "Other",        symbol: "macwindow")
        }
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
