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
        // Validate: hex + dashes only, 8–64 chars — never interpolate raw input.
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF-")
        guard (8...64).contains(terminalID.count),
              terminalID.unicodeScalars.allSatisfy(allowed.contains)
        else { return }

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
}
