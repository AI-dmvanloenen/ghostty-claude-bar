import SwiftUI

/// A status indicator that pulses a halo when the state is "live" (working).
/// The dot itself glows with the state color; live states emit an expanding ring.
struct StatusDot: View {
    let style: StateStyle
    var size: CGFloat = 9

    @State private var pulse = false

    var body: some View {
        ZStack {
            if style.isLive {
                Circle()
                    .stroke(style.color, lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 0.7)
            }
            Circle()
                .fill(style.color)
                .frame(width: size, height: size)
                .shadow(color: style.color.opacity(0.9), radius: style.isLive ? 5 : 2.5)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard style.isLive else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
