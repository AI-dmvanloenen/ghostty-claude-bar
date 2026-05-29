import SwiftUI

/// Settings, styled to match the mission-control surface. Refresh cadence is
/// applied live; the Stop-hook judging model is noted as later work.
struct SettingsView: View {
    @ObservedObject var monitor: SessionMonitor
    @State private var interval: TimeInterval = AppSettings.refreshInterval

    var body: some View {
        ZStack(alignment: .topLeading) {
            AmbientBackground(accent: Color(hex: 0x2A3140))
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(Theme.display(17, .semibold))
                    .foregroundStyle(Theme.textPrimary)

                card {
                    Text("REFRESH CADENCE")
                        .font(Theme.display(10, .bold)).tracking(1.2)
                        .foregroundStyle(Theme.textSecondary)
                    Picker("", selection: $interval) {
                        ForEach(AppSettings.refreshOptions, id: \.seconds) { opt in
                            Text(opt.label).tag(opt.seconds)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: interval) { _, newValue in
                        AppSettings.refreshInterval = newValue
                        monitor.setInterval(newValue)
                    }
                    Text("The menu bar also updates instantly when a session starts, stops, or finishes a turn — this is just the backstop interval.")
                        .font(Theme.text(11)).foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                card {
                    Text("DONE / WAITING DETECTION")
                        .font(Theme.display(10, .bold)).tracking(1.2)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Sessions turn green the moment Claude finishes a turn, judged by the Stop hook. Installing and configuring that hook (including the model) comes in a later release.")
                        .font(Theme.text(11)).foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                Text("ghostty-claude-bar · early development")
                    .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary.opacity(0.7))
            }
            .padding(24)
        }
        .frame(width: 440, height: 380, alignment: .topLeading)
        .preferredColorScheme(.dark)
        .tint(Color(hex: 0x5FD08A))
    }

    @ViewBuilder private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }
}
