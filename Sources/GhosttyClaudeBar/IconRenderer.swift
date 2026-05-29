import AppKit
import GhosttyClaudeBarCore

/// Draws the menu-bar glyph and the per-row status dots.
///
/// Going native is the whole point here: we control every `NSImage` directly,
/// so the SwiftBar-era pain — vibrancy desaturating `sfcolor`, the `sfconfig`
/// Palette-mode workaround, washed-out dropdowns — simply does not exist. A
/// `circle.fill` rendered with a palette color shows full-strength.
@MainActor
struct IconRenderer {
    /// Status-bar template glyph. Shape (not color) signals "needs reply",
    /// per the native menu-bar convention.
    func statusBarImage(needsReply: Bool) -> NSImage {
        let name = needsReply ? "macwindow.badge.plus" : "macwindow"
        let image = NSImage(systemSymbolName: name,
                            accessibilityDescription: "Claude Code sessions")
            ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// A colored status dot for a menu row.
    func dotImage(for state: SessionState) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color(for: state)]))
        let base = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
            ?? NSImage()
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = false
        return image
    }

    private func color(for state: SessionState) -> NSColor {
        switch state {
        case .working:     return NSColor(hex: 0xE0726B) // red
        case .needsReply:  return NSColor(hex: 0xE0A458) // orange
        case .idle:        return NSColor(hex: 0xD4C46A) // yellow
        case .safeToClose: return NSColor.systemGreen
        case .other:       return NSColor.secondaryLabelColor
        }
    }
}

extension NSColor {
    /// 0xRRGGBB convenience.
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
