import SwiftUI

/// Minimal but real settings: refresh cadence (applied live). The Stop-hook
/// judging model lives with hook management (Phase 5), noted here for context.
struct SettingsView: View {
    @ObservedObject var monitor: SessionMonitor
    @State private var interval: TimeInterval = AppSettings.refreshInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh cadence").font(.subheadline).foregroundStyle(.secondary)
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
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Done / waiting detection")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Sessions turn green the moment Claude finishes a turn, judged by the Stop hook. Installing and configuring that hook (incl. the model) comes in a later release.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Text("ghostty-claude-bar · early development")
                .font(.caption2).foregroundStyle(.quaternary)
        }
        .padding(22)
        .frame(width: 420, height: 320, alignment: .topLeading)
    }
}
