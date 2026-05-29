import Foundation
import GhosttyClaudeBarCore

/// Runs the `claude` CLI headlessly (Haiku) for the judge + name suggester.
/// No API key — uses the user's existing Claude Code auth. Guards against the
/// recursion its own call would trigger (its Stop hook re-invokes our binary)
/// and registers the spawned PID so the transient session doesn't ghost the UI.
enum ClaudeCLI {
    /// Returns trimmed stdout, or nil if `claude` can't be found / errored.
    static func run(_ prompt: String) -> String? {
        guard let claude = path() else { return nil }
        var env = ProcessInfo.processInfo.environment
        env["GCB_JUDGE"] = "1" // recursion guard: our Stop hook no-ops on this
        return exec(claude, ["-p", "--model", "haiku", prompt], env: env)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func path() -> String? {
        if let override = ProcessInfo.processInfo.environment["GCB_CLAUDE"],
           FileManager.default.isExecutableFile(atPath: override) { return override }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for p in ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        where FileManager.default.isExecutableFile(atPath: p) { return p }
        if let found = exec("/bin/zsh", ["-lc", "command -v claude"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !found.isEmpty,
           FileManager.default.isExecutableFile(atPath: found) { return found }
        return nil
    }

    private static func exec(_ launch: String, _ args: [String], env: [String: String]? = nil) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launch)
        process.arguments = args
        if let env { process.environment = env }
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }

        // `claude -p` spawns a transient session file — hide it from the UI.
        let pid = Int(process.processIdentifier)
        let registered = env?["GCB_JUDGE"] != nil
        if registered { IgnoredPIDs.shared.add(pid) }
        defer { if registered { IgnoredPIDs.shared.remove(pid) } }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
