import SwiftUI
import GhosttyClaudeBarCore

/// The native report window: every live Claude Code session, grouped by state,
/// with a colored accent, age, token/cost, last-message preview, and a focus
/// action. Updates live from `SessionMonitor`.
struct ReportView: View {
    @ObservedObject var monitor: SessionMonitor
    /// Focus a Ghostty window by terminal UUID.
    var onFocus: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .frame(minWidth: 580, minHeight: 440)
        .background(WindowBackground())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Code Sessions")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                summaryPills
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    monitor.refreshAsync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
                Text(updatedText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var summaryPills: some View {
        HStack(spacing: 6) {
            ForEach(monitor.grouped(), id: \.state) { group in
                let style = StateStyle.of(group.state)
                HStack(spacing: 4) {
                    Circle().fill(style.color).frame(width: 7, height: 7)
                    Text("\(group.rows.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(style.color.opacity(0.12), in: Capsule())
            }
            if monitor.rows.isEmpty {
                Text("no sessions").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var updatedText: String {
        guard monitor.lastUpdated != .distantPast else { return "—" }
        let secs = Int(Date().timeIntervalSince(monitor.lastUpdated))
        if secs < 2 { return "updated just now" }
        if secs < 60 { return "updated \(secs)s ago" }
        return "updated \(secs / 60)m ago"
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if monitor.rows.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(monitor.grouped(), id: \.state) { group in
                        Section {
                            VStack(spacing: 8) {
                                ForEach(group.rows) { row in
                                    SessionRowView(row: row, onFocus: onFocus)
                                }
                            }
                        } header: {
                            SectionHeaderView(state: group.state, count: group.rows.count)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No open Ghostty windows")
                .font(.headline).foregroundStyle(.secondary)
            Text("Open a Ghostty window running Claude Code and it'll show up here.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Section header

private struct SectionHeaderView: View {
    let state: SessionState
    let count: Int

    var body: some View {
        let style = StateStyle.of(state)
        HStack(spacing: 7) {
            Image(systemName: style.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(style.color)
            Text(style.label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Row

private struct SessionRowView: View {
    let row: TabRow
    var onFocus: (String) -> Void
    @State private var hovering = false

    private var style: StateStyle { StateStyle.of(row.state) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(style.color).frame(width: 3).opacity(0.9)
            details
            focusGlyph
        }
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if let id = row.terminalID { onFocus(id) } }
        .help(row.terminalID != nil ? "Click to focus this Ghostty window" : "No window to focus")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            titleRow
            metaRow
            if let reason = row.reason {
                Text(reason)
                    .font(.system(size: 11))
                    .foregroundStyle(style.color.opacity(0.95))
                    .lineLimit(1)
            }
            if let last = row.lastMessage, !last.isEmpty {
                Text(last)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let age = row.ageText {
                Text(age)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
        }
    }

    @ViewBuilder private var metaRow: some View {
        HStack(spacing: 8) {
            if let cwd = row.cwd, !cwd.isEmpty {
                Label(cwd, systemImage: "folder")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let win = row.windowLabel {
                Text(win)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            if let tokens = row.tokensText {
                Text("·").foregroundStyle(.tertiary)
                Text(tokens + (row.costText.map { "  \($0)" } ?? ""))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private var focusGlyph: some View {
        if row.terminalID != nil {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 13))
                .foregroundStyle(hovering ? style.color : Color.secondary)
                .padding(.trailing, 12)
                .padding(.top, 11)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(hovering ? style.color.opacity(0.10) : Color.primary.opacity(0.04))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 9)
            .strokeBorder(hovering ? style.color.opacity(0.35) : Color.clear, lineWidth: 1)
    }
}

/// Subtle adaptive window backing.
private struct WindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
