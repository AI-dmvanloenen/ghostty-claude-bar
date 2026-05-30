import Foundation

/// Talks to Ghostty over AppleScript (`osascript`). Ghostty exposes window / tab
/// / terminal objects; `name` of a tab is the Claude-Code-set title.
public enum GhosttyClient {
    private static let enumerateScript = """
    tell application "Ghostty"
      set out to ""
      set sep to "|||"
      repeat with w from 1 to count of windows
        set theWin to window w
        repeat with t from 1 to count of tabs of theWin
          set theTab to tab t of theWin
          set termId to ""
          try
            set termId to id of terminal 1 of theTab
          end try
          set out to out & w & sep & t & sep & termId & sep & (name of theTab) & linefeed
        end repeat
      end repeat
      return out
    end tell
    """

    /// One-frame anti-flicker: a transient osascript hiccup (or a watchdog
    /// termination) can momentarily yield zero tabs while windows are actually
    /// open. We reuse the last good result for ONE such frame; a genuine
    /// "all windows closed" (empty twice running) is accepted.
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var lastGood: [GhosttyTab] = []
        var suppressedFrames = 0
    }
    private static let cache = Cache()

    /// Enumerate all open Ghostty tabs.
    public static func tabs() -> [GhosttyTab] {
        let parsed = parseTabs()

        cache.lock.lock()
        defer { cache.lock.unlock() }
        if parsed.isEmpty, !cache.lastGood.isEmpty, cache.suppressedFrames < 1 {
            cache.suppressedFrames += 1
            return cache.lastGood
        }
        cache.suppressedFrames = 0
        cache.lastGood = parsed
        return parsed
    }

    private static func parseTabs() -> [GhosttyTab] {
        guard let out = Shell.run("/usr/bin/osascript", ["-"], stdin: enumerateScript, timeout: 5) else {
            return []
        }
        var result: [GhosttyTab] = []
        for line in out.split(separator: "\n") {
            let parts = line.components(separatedBy: "|||")
            guard parts.count == 4,
                  let window = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  let tab = Int(parts[1].trimmingCharacters(in: .whitespaces))
            else { continue }
            result.append(GhosttyTab(
                window: window,
                tab: tab,
                terminalID: parts[2].trimmingCharacters(in: .whitespaces),
                title: parts[3].trimmingCharacters(in: .whitespaces)
            ))
        }
        return result
    }

    /// Focus the window owning a terminal, by its stable UUID. Window indices are
    /// unstable (Ghostty reorders on focus), so we always target the id.
    public static func focus(terminalID: String) {
        guard isValidID(terminalID) else { return }
        let script = """
        tell application "Ghostty"
          activate
          try
            set theTerm to first terminal whose id is "\(terminalID)"
            focus theTerm
          end try
        end tell
        """
        Shell.run("/usr/bin/osascript", ["-e", script])
    }

    /// Type text into a terminal (Ghostty's `input text` command, added in newer
    /// versions — verified in the sdef). `submit` appends a return so it's sent
    /// as a command. Used to fire `/close` into a session from the dashboard.
    public static func sendText(_ text: String, toTerminal id: String, submit: Bool = true) {
        guard isValidID(id) else { return }
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // Claude Code submits on the Enter KEY, not a carriage-return character,
        // so we type the text then send a real `enter` key event.
        let submitLine = submit
            ? "\n            delay 0.1\n            send key \"enter\" to theTerm"
            : ""
        let script = """
        tell application "Ghostty"
          try
            set theTerm to (first terminal whose id is "\(id)")
            input text "\(escaped)" to theTerm\(submitLine)
          end try
        end tell
        """
        Shell.run("/usr/bin/osascript", ["-e", script])
    }

    /// Open a new Ghostty window directly in `directory`. We only set the working
    /// directory — the user's shell/Ghostty config launches `claude` itself (it
    /// auto-starts in new windows), so injecting `claude` would double it up.
    public static func newSession(directory: String) {
        let dir = directory
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Ghostty"
          activate
          set cfg to new surface configuration
          set initial working directory of cfg to "\(dir)"
          new window with configuration cfg
        end tell
        """
        Shell.run("/usr/bin/osascript", ["-e", script], timeout: 8)
    }

    /// Terminal UUIDs are hex + dashes, 8–64 chars — never interpolate raw input.
    private static func isValidID(_ id: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF-")
        return (8...64).contains(id.count) && id.unicodeScalars.allSatisfy(allowed.contains)
    }
}
