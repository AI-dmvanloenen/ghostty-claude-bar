import SwiftUI
import GhosttyClaudeBarCore

/// The native report window — a dark "mission control" surface listing every
/// live Claude Code session, grouped by state, over an ambient glow that tracks
/// the most urgent state. Updates live from `SessionMonitor`.
struct ReportView: View {
    @ObservedObject var monitor: SessionMonitor
    /// Focus a Ghostty window by terminal UUID.
    var onFocus: (String) -> Void

    private var dominant: Color {
        StateStyle.dominantColor(for: monitor.rows.map(\.state))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(accent: dominant)
            VStack(spacing: 0) {
                HeaderView(monitor: monitor)
                Rectangle().fill(Theme.hairline).frame(height: 1)
                content
            }
        }
        .frame(minWidth: 600, minHeight: 460)
        .preferredColorScheme(.dark)
        .tint(dominant)
    }

    @ViewBuilder private var content: some View {
        if monitor.rows.isEmpty {
            EmptyStateView().frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(monitor.grouped().enumerated()), id: \.element.state) { _, group in
                        VStack(alignment: .leading, spacing: Theme.rowSpacing) {
                            SectionHeaderView(state: group.state, count: group.rows.count)
                            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                                SessionRowView(row: row, index: index, onFocus: onFocus)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var monitor: SessionMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Claude Code Sessions")
                    .font(Theme.display(20, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                SummaryReadout(monitor: monitor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                RefreshButton { monitor.refreshAsync() }
                Text(updatedText)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var updatedText: String {
        guard monitor.lastUpdated != .distantPast else { return "—" }
        let secs = Int(Date().timeIntervalSince(monitor.lastUpdated))
        if secs < 2 { return "updated just now" }
        if secs < 60 { return "updated \(secs)s ago" }
        return "updated \(secs / 60)m ago"
    }
}

private struct SummaryReadout: View {
    @ObservedObject var monitor: SessionMonitor

    var body: some View {
        HStack(spacing: 5) {
            if monitor.rows.isEmpty {
                Text("no sessions")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textTertiary)
            }
            ForEach(monitor.grouped(), id: \.state) { group in
                let style = StateStyle.of(group.state)
                HStack(spacing: 5) {
                    StatusDot(style: style, size: 6)
                    Text("\(group.rows.count)")
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(style.color.opacity(0.12))
                        .overlay(Capsule().strokeBorder(style.color.opacity(0.25), lineWidth: 0.5))
                )
            }
        }
    }
}

private struct RefreshButton: View {
    let action: () -> Void
    @State private var hovering = false
    @State private var spin = false

    var body: some View {
        Button {
            spin.toggle()
            action()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.easeInOut(duration: 0.6), value: spin)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Refresh now")
    }
}

// MARK: - Section header

private struct SectionHeaderView: View {
    let state: SessionState
    let count: Int

    var body: some View {
        let style = StateStyle.of(state)
        HStack(spacing: 8) {
            Image(systemName: style.symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(style.color)
            Text(style.label.uppercased())
                .font(Theme.display(10, .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            Text("\(count)")
                .font(Theme.mono(10, .semibold))
                .foregroundStyle(Theme.textTertiary)
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.leading, 4)
        }
        .padding(.bottom, 1)
    }
}

// MARK: - Row

private struct SessionRowView: View {
    let row: TabRow
    let index: Int
    var onFocus: (String) -> Void

    @State private var hovering = false
    @State private var appeared = false

    private var style: StateStyle { StateStyle.of(row.state) }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            StatusDot(style: style, size: 9)
                .padding(.top, 3)
            details
            focusGlyph
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
        .overlay(accentEdge, alignment: .leading)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: hovering ? 10 : 0, y: hovering ? 4 : 0)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if let id = row.terminalID { onFocus(id) } }
        .help(row.terminalID != nil ? "Click to focus this Ghostty window" : "No window to focus")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.045)) {
                appeared = true
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            metaRow
            if let reason = row.reason {
                Text(reason)
                    .font(Theme.text(11, .medium))
                    .foregroundStyle(style.color)
                    .lineLimit(1)
            }
            if let last = row.lastMessage, !last.isEmpty {
                Text(last)
                    .font(Theme.text(11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
                    .padding(.top, 1)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.title)
                .font(Theme.display(13.5, .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let age = row.ageText {
                Text(age)
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(Capsule().fill(Theme.cardRaised))
            }
        }
    }

    @ViewBuilder private var metaRow: some View {
        HStack(spacing: 8) {
            if let cwd = row.cwd, !cwd.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "folder").font(.system(size: 9))
                    Text(cwd).font(Theme.mono(10))
                }
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            }
            if let win = row.windowLabel {
                Text(win).font(Theme.mono(9, .medium)).foregroundStyle(Theme.textTertiary)
            }
            if let tokens = row.tokensText {
                Text("·").foregroundStyle(Theme.textTertiary)
                Text(tokens).font(Theme.mono(9)).foregroundStyle(Theme.textTertiary)
                if let cost = row.costText {
                    Text(cost).font(Theme.mono(9, .medium)).foregroundStyle(style.color.opacity(0.85))
                }
            }
        }
    }

    @ViewBuilder private var focusGlyph: some View {
        if row.terminalID != nil {
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.system(size: 13))
                .foregroundStyle(hovering ? style.color : Theme.textTertiary.opacity(0.5))
                .padding(.top, 2)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(hovering ? style.color.opacity(0.10) : Theme.card)
    }

    private var accentEdge: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(style.color)
            .frame(width: 3)
            .shadow(color: style.color.opacity(0.7), radius: hovering ? 4 : 2)
            .padding(.vertical, 6)
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .strokeBorder(hovering ? style.color.opacity(0.4) : Theme.hairline, lineWidth: 1)
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(Theme.textTertiary)
            Text("No open Ghostty windows")
                .font(Theme.display(15, .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("Open a Ghostty window running Claude Code\nand it'll show up here.")
                .font(Theme.text(11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
