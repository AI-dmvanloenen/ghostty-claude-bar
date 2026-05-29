import Foundation

/// The state of a Claude Code session as surfaced in the menu bar.
/// Ordering of the cases is the menu sort order (working first, other last).
public enum SessionState: String, Sendable, CaseIterable {
    case working      // a turn is actively running  → red
    case needsReply   // finished, waiting on you     → orange
    case idle         // alive but quiet              → yellow
    case safeToClose  // done + stale, fine to close  → green
    case other        // a Ghostty window with no tracked Claude session → gray
}

/// One row in the menu — a Ghostty window, enriched with session data when matched.
/// Tab-centric (see the Python tool's hard-won lesson): every window gets a row.
public struct TabRow: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let cwd: String?
    /// Human age like "2h", "38s" — nil when unknown.
    public let ageText: String?
    public let state: SessionState
    /// One-line explanation of the state ("busy — working now", "idle 3.2h"). Tooltip fodder.
    public let reason: String?
    /// Stable Ghostty terminal UUID, used to focus the window. nil for orphan rows.
    public let terminalID: String?

    // Richer fields for the report window (the menu uses only the above).
    /// "W3" or "W3·T2" for multi-tab windows; "—" for orphan sessions; nil for shells.
    public let windowLabel: String?
    public let pid: Int?
    public let status: String?
    public let tokens: Int
    public let tokensText: String?
    public let costText: String?
    public let costUSD: Double?
    /// First line of the last assistant message, for a preview.
    public let lastMessage: String?

    public init(
        id: String,
        title: String,
        cwd: String? = nil,
        ageText: String? = nil,
        state: SessionState,
        reason: String? = nil,
        terminalID: String? = nil,
        windowLabel: String? = nil,
        pid: Int? = nil,
        status: String? = nil,
        tokens: Int = 0,
        tokensText: String? = nil,
        costText: String? = nil,
        costUSD: Double? = nil,
        lastMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.cwd = cwd
        self.ageText = ageText
        self.state = state
        self.reason = reason
        self.terminalID = terminalID
        self.windowLabel = windowLabel
        self.pid = pid
        self.status = status
        self.tokens = tokens
        self.tokensText = tokensText
        self.costText = costText
        self.costUSD = costUSD
        self.lastMessage = lastMessage
    }

    /// Title as shown in the menu. Age is appended inline for now; Phase 2 will
    /// move it to a right-aligned attributed badge.
    public var menuTitle: String {
        if let ageText, !ageText.isEmpty {
            return "\(title)  ·  \(ageText)"
        }
        return title
    }
}
