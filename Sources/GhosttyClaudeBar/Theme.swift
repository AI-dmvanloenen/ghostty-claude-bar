import SwiftUI

/// Design tokens for the "mission control" aesthetic: a self-contained dark
/// surface (consistent regardless of system appearance), cool grays, sharp
/// state accents, monospaced telemetry, rounded display type.
enum Theme {
    // Surfaces
    static let base       = Color(hex: 0x0E1014)
    static let baseDeep   = Color(hex: 0x080A0D)
    static let card       = Color.white.opacity(0.035)
    static let cardRaised = Color.white.opacity(0.06)
    static let hairline   = Color.white.opacity(0.07)

    // Text
    static let textPrimary   = Color(hex: 0xEDEFF2)
    static let textSecondary = Color(hex: 0x97A0AD)
    static let textTertiary  = Color(hex: 0x5B6573)

    // Type — rounded display, monospaced telemetry.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // Geometry
    static let cardRadius: CGFloat = 12
    static let rowSpacing: CGFloat = 7
}
