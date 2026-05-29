import AppKit

/// Draws the app/Dock/Cmd-Tab icon at runtime (the dev binary has no bundled
/// .icns, so without this macOS shows a generic "EXEC" placeholder). On-brand:
/// a dark squircle with a window glyph and the three signature status dots.
@MainActor
enum AppIcon {
    static func install() {
        NSApp.applicationIconImage = make()
    }

    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let squircle = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)

        // Dark gradient body.
        NSGradient(colors: [NSColor(hex: 0x1D2330), NSColor(hex: 0x0B0D11)])?
            .draw(in: squircle, angle: -90)

        // Warm ambient glow from the top.
        squircle.addClip()
        NSGradient(colors: [NSColor(hex: 0xF7B25C).withAlphaComponent(0.30), .clear])?
            .draw(fromCenter: NSPoint(x: size * 0.5, y: size * 0.92), radius: 0,
                  toCenter: NSPoint(x: size * 0.5, y: size * 0.92), radius: size * 0.62,
                  options: [])

        // Window glyph, light, upper-centre.
        let glyphConfig = NSImage.SymbolConfiguration(pointSize: size * 0.40, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(hex: 0xEDEFF2)]))
        if let glyph = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)?
            .withSymbolConfiguration(glyphConfig) {
            let gs = glyph.size
            glyph.draw(in: NSRect(x: (size - gs.width) / 2, y: size * 0.40,
                                  width: gs.width, height: gs.height))
        }

        // Three signature status dots.
        let dotColors = [NSColor(hex: 0xFF6B66), NSColor(hex: 0xF7B25C), NSColor(hex: 0x5FD08A)]
        let r = size * 0.050
        let gap = size * 0.085
        let totalW = CGFloat(dotColors.count - 1) * gap
        let startX = size * 0.5 - totalW / 2
        let y = size * 0.26
        for (i, color) in dotColors.enumerated() {
            let cx = startX + CGFloat(i) * gap
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx - r, y: y - r, width: r * 2, height: r * 2)).fill()
        }

        image.unlockFocus()
        return image
    }
}
