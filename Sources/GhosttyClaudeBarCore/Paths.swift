import Foundation

/// Well-known Claude Code locations under `~/.claude`.
public enum Paths {
    public static let home = FileManager.default.homeDirectoryForCurrentUser.path
    public static var sessionsDir: String { home + "/.claude/sessions" }
    public static var projectsDir: String { home + "/.claude/projects" }

    /// Claude Code's project-dir encoding maps `/ _ space & .` all to `-`.
    /// The trailing `.` is essential: omitting it breaks any dotted cwd
    /// (e.g. `~/.claude/...`) → transcript not found → session never matches
    /// its window (the phantom-orphan bug the Python tool hit).
    public static func encodeCwd(_ cwd: String) -> String {
        var s = cwd
        for ch in ["/", "_", " ", "&", "."] {
            s = s.replacingOccurrences(of: ch, with: "-")
        }
        return s
    }

    /// Resolved transcript path for a session, or nil if it doesn't exist.
    public static func transcriptPath(sessionId: String, cwd: String) -> String? {
        let p = "\(projectsDir)/\(encodeCwd(cwd))/\(sessionId).jsonl"
        return FileManager.default.fileExists(atPath: p) ? p : nil
    }

    /// Collapse the home prefix to `~` for display.
    public static func collapseHome(_ path: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
