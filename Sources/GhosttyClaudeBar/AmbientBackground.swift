import SwiftUI
import CoreImage

/// The signature surface: a near-black base with an ambient glow tinted by the
/// most urgent active state, a cool secondary glow for depth, and a faint grain
/// overlay. The glow color animates as the situation changes — so the window
/// itself reads as "something's working" / "all clear" before you read a word.
struct AmbientBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.base, Theme.baseDeep],
                startPoint: .top, endPoint: .bottom
            )

            RadialGradient(
                colors: [accent.opacity(0.28), .clear],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 460
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [Color(hex: 0x1B2740).opacity(0.55), .clear],
                center: .init(x: 1.05, y: 1.05),
                startRadius: 0, endRadius: 520
            )

            GrainOverlay()
                .opacity(0.05)
        }
        .animation(.easeInOut(duration: 0.9), value: accent)
        .ignoresSafeArea()
    }
}

/// A tileable monochrome noise image, generated once, blended at low opacity to
/// give the flat dark surface some tooth.
private struct GrainOverlay: View {
    var body: some View {
        if let image = Grain.shared {
            Image(nsImage: image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

private enum Grain {
    static let shared: NSImage? = make(size: 220)

    static func make(size: Int) -> NSImage? {
        let context = CIContext()
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let mono = noise
            .cropped(to: rect)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.2,
                kCIInputBrightnessKey: 0.0,
            ])
        guard let cg = context.createCGImage(mono, from: rect) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }
}
