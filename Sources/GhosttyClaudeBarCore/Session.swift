import Foundation

/// A live Claude Code session, parsed from `~/.claude/sessions/<pid>.json`.
public struct Session: Sendable {
    public let pid: Int
    public let sessionId: String
    public let cwd: String
    public let status: String?
    /// Epoch milliseconds, as Claude Code writes them.
    public let startedAt: Double
    public let updatedAt: Double
    /// Resolved transcript path, filled in by the collector.
    public var jsonlPath: String?

    public init(
        pid: Int,
        sessionId: String,
        cwd: String,
        status: String?,
        startedAt: Double,
        updatedAt: Double,
        jsonlPath: String? = nil
    ) {
        self.pid = pid
        self.sessionId = sessionId
        self.cwd = cwd
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.jsonlPath = jsonlPath
    }

    /// Age in hours since the last update (falls back to start time).
    public func ageHours(now: Date) -> Double {
        let ms = updatedAt != 0 ? updatedAt : startedAt
        guard ms != 0 else { return 0 }
        return (now.timeIntervalSince1970 - ms / 1000) / 3600
    }
}

/// One Ghostty tab as reported by AppleScript. Window/tab indices are unstable
/// (Ghostty reorders on focus) — only `terminalID` is safe to act on.
public struct GhosttyTab: Sendable {
    public let window: Int
    public let tab: Int
    public let terminalID: String
    public let title: String

    public init(window: Int, tab: Int, terminalID: String, title: String) {
        self.window = window
        self.tab = tab
        self.terminalID = terminalID
        self.title = title
    }
}
