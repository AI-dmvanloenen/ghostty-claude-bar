import SwiftUI
import Combine
import GhosttyClaudeBarCore

/// The native report window — a dark "mission control" surface listing every
/// live Claude Code session, grouped by state, over an ambient glow that tracks
/// the most urgent state. Bundled type (Martian Mono / IBM Plex Mono), animated.
struct ReportView: View {
    @ObservedObject var monitor: SessionMonitor
    var onFocus: (String) -> Void

    private var dominant: Color {
        StateStyle.dominantColor(for: monitor.rows.map(\.state))
    }
    private var animationKey: [String] {
        monitor.rows.map { "\($0.id):\($0.state.rawValue)" }
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
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(monitor.grouped(), id: \.state) { group in
                        VStack(alignment: .leading, spacing: 7) {
                            SectionHeaderView(state: group.state, count: group.rows.count)
                            ForEach(group.rows) { row in
                                SessionRowView(row: row, maxTokens: monitor.maxTokens, onFocus: onFocus)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .animation(.smooth(duration: 0.4), value: animationKey)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var monitor: SessionMonitor
    @State private var now = Date()

    private var accent: Color { StateStyle.dominantColor(for: monitor.rows.map(\.state)) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.6), radius: 5)
                    Text("CLAUDE CODE SESSIONS")
                        .font(Theme.display(13, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.textPrimary)
                }
                StatusStrip(monitor: monitor)
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
        .padding(.top, 30)
        .padding(.bottom, 16)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var updatedText: String {
        guard monitor.lastUpdated != .distantPast else { return "—" }
        let secs = max(0, Int(now.timeIntervalSince(monitor.lastUpdated)))
        if secs < 2 { return "updated just now" }
        if secs < 60 { return "updated \(secs)s ago" }
        return "updated \(secs / 60)m ago"
    }
}

/// One compact line: per-state counts + aggregate tokens/cost.
private struct StatusStrip: View {
    @ObservedObject var monitor: SessionMonitor

    var body: some View {
        HStack(spacing: 9) {
            if monitor.rows.isEmpty {
                Text("no live sessions").font(Theme.mono(11)).foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(monitor.grouped(), id: \.state) { group in
                    let style = StateStyle.of(group.state)
                    HStack(spacing: 5) {
                        StatusDot(style: style, size: 6)
                        Text("\(group.rows.count)")
                            .font(Theme.mono(11, .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if monitor.totalTokens > 0 {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 11)
                    Text("↓ \(Usage.fmtTokens(monitor.totalTokens))")
                        .font(Theme.mono(11)).foregroundStyle(Theme.textTertiary)
                    Text("$\(String(format: "%.0f", monitor.totalCost))")
                        .font(Theme.mono(11, .medium)).foregroundStyle(Theme.textSecondary)
                }
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
            spin.toggle(); action()
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
                .font(Theme.display(9.5, .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)
            Text("\(count)")
                .font(Theme.mono(9.5, .medium))
                .foregroundStyle(Theme.textTertiary)
            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 4)
        }
        .padding(.bottom, 1)
    }
}

// MARK: - Row

private struct SessionRowView: View {
    let row: TabRow
    let maxTokens: Int
    var onFocus: (String) -> Void

    @State private var hovering = false

    private var style: StateStyle { StateStyle.of(row.state) }
    private var prominent: Bool { row.state == .working }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            AccentEdge(color: style.color, live: style.isLive)
            StatusDot(style: style, size: 9).padding(.top, 2)
            details
            focusGlyph
        }
        .padding(.leading, 0)
        .padding(.trailing, 14)
        .padding(.vertical, prominent ? 12 : 10)
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: hovering ? 10 : 0, y: hovering ? 4 : 0)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if let id = row.terminalID { onFocus(id) } }
        .help(row.terminalID != nil ? "Click to focus this Ghostty window" : "No matching window to focus")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            titleRow
            metaRow
            if let reason = row.reason {
                Text(reason)
                    .font(Theme.mono(10.5, .medium))
                    .foregroundStyle(style.color)
                    .lineLimit(1)
            }
            tokenBar
            if let last = row.lastMessage, !last.isEmpty {
                Text(last)
                    .font(Theme.text(10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(prominent ? 2 : 1)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 2)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.title)
                .font(Theme.mono(prominent ? 13 : 12.5, .semibold))
                .foregroundStyle(prominent ? Theme.textPrimary : Theme.textPrimary.opacity(0.92))
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
            if let win = row.windowLabel, win != "—" {
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

    @ViewBuilder private var tokenBar: some View {
        if row.tokens > 0, maxTokens > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline).frame(height: 2.5)
                    Capsule().fill(style.color.opacity(0.7))
                        .frame(width: max(3, geo.size.width * CGFloat(row.tokens) / CGFloat(maxTokens)), height: 2.5)
                }
            }
            .frame(height: 2.5)
            .padding(.top, 2)
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
            .fill(hovering ? style.color.opacity(0.10) : (prominent ? Theme.cardRaised : Theme.card))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .strokeBorder(hovering ? style.color.opacity(0.4) : Theme.hairline, lineWidth: 1)
    }
}

/// The left accent bar — with a vertical shimmer when the state is "live" (working).
private struct AccentEdge: View {
    let color: Color
    let live: Bool
    @State private var phase = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3)
            .overlay(shimmer)
            .shadow(color: color.opacity(0.6), radius: 2)
            .padding(.vertical, 5)
    }

    @ViewBuilder private var shimmer: some View {
        if live {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.45)
                    .offset(y: phase ? geo.size.height : -geo.size.height * 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = true
                }
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(Theme.textTertiary)
            Text("No live Claude sessions")
                .font(Theme.display(13, .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Start Claude Code in a Ghostty window\nand it'll show up here.")
                .font(Theme.text(11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
