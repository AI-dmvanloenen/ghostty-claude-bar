import Foundation
import GhosttyClaudeBarCore

/// Installs / removes the app's Claude Code hooks in `~/.claude/settings.json`.
///
/// Safe by construction: it backs the file up first, parses it as generic JSON
/// (preserving every key it doesn't own — permissions, env, other hooks…),
/// removes only its own prior entries (idempotent) plus the legacy
/// `tabs-on-stop.py` Stop hook (which writes the same sidecar and would race),
/// then writes atomically. `uninstall` removes only what it added.
enum HookInstaller {
    private static var settingsPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/settings.json"
    }

    /// Absolute path to this binary, quoted for the shell. The hook command is
    /// re-pointed here on every install, so moving/repackaging + re-installing
    /// just works.
    private static var selfCommand: String {
        let path = Bundle.main.executablePath
            ?? CommandLine.arguments.first
            ?? "ghostty-claude-bar"
        return "\"\(path)\""
    }

    @discardableResult
    static func install() -> String {
        var root = loadSettings()
        backup()

        var hooks = root["hooks"] as? [String: Any] ?? [:]

        hooks["Stop"] = upsert(
            event: hooks["Stop"] as? [[String: Any]] ?? [],
            removingCommandsContaining: ["tabs-on-stop.py", "ghostty-claude-bar"],
            adding: "\(selfCommand) --stop-hook"
        )
        hooks["Notification"] = upsert(
            event: hooks["Notification"] as? [[String: Any]] ?? [],
            removingCommandsContaining: ["ghostty-claude-bar"],
            adding: "\(selfCommand) --notify-hook"
        )

        root["hooks"] = hooks
        write(root)
        return "Installed Stop + Notification hooks → \(selfCommand). Backed up settings.json. Removed legacy tabs-on-stop.py Stop hook."
    }

    @discardableResult
    static func uninstall() -> String {
        var root = loadSettings()
        backup()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in ["Stop", "Notification"] {
            let groups = hooks[event] as? [[String: Any]] ?? []
            hooks[event] = stripCommands(from: groups, containing: ["ghostty-claude-bar"])
        }
        root["hooks"] = hooks
        write(root)
        return "Removed ghostty-claude-bar hooks from settings.json (backup written)."
    }

    // MARK: - JSON helpers

    /// Drop our managed hooks, prune empty groups, then append one fresh group.
    private static func upsert(event: [[String: Any]], removingCommandsContaining needles: [String], adding command: String) -> [[String: Any]] {
        var groups = stripCommands(from: event, containing: needles)
        groups.append(["hooks": [["type": "command", "command": command]]])
        return groups
    }

    /// Remove any hook whose command contains one of `needles`; drop now-empty groups.
    private static func stripCommands(from groups: [[String: Any]], containing needles: [String]) -> [[String: Any]] {
        groups.compactMap { group -> [String: Any]? in
            var g = group
            let hooks = (g["hooks"] as? [[String: Any]] ?? []).filter { hook in
                let cmd = hook["command"] as? String ?? ""
                return !needles.contains { cmd.contains($0) }
            }
            if hooks.isEmpty { return nil }
            g["hooks"] = hooks
            return g
        }
    }

    private static func loadSettings() -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return d
    }

    private static func backup() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: settingsPath) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        try? fm.copyItem(atPath: settingsPath, toPath: "\(settingsPath).bak-gcb-\(stamp)")
    }

    private static func write(_ root: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return }
        try? data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }
}
