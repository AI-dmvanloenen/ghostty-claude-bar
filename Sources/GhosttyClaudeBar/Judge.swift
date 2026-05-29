import Foundation
import GhosttyClaudeBarCore

/// Classifies a finished turn as DONE / WAITING / ACTIVE by calling Haiku through
/// the `claude` CLI (no API key — uses the user's existing Claude Code auth).
/// Falls back to the heuristic if `claude` can't be found or errors.
enum Judge {
    /// Synchronous (call from a detached task). ~a few seconds.
    static func classify(lastMessage: String?) -> String {
        guard let msg = lastMessage, !msg.isEmpty else { return "ACTIVE" }
        guard let claude = claudePath() else { return Recommender.heuristicState(lastText: msg) }

        let prompt = """
        Classify the assistant's final message in a coding session. Reply with EXACTLY one word, nothing else.
        WAITING — it asks the user anything, requests a decision/permission/input, or offers options for the user to pick. A question addressed to the user means WAITING.
        DONE — the task is finished with nothing left for the user to do.
        ACTIVE — it is narrating in-progress work it will continue on its own, no user input needed.

        Message:
        \(String(msg.prefix(4000)))
        """

        var env = ProcessInfo.processInfo.environment
        env["GCB_JUDGE"] = "1" // recursion guard: our hook no-ops when it sees this

        // `claude -p` creates a transient session file; register its PID so the
        // collector doesn't flicker it in as a ghost row.
        let out = (run(claude, ["-p", "--model", "haiku", prompt], env: env, registerPID: true) ?? "").uppercased()
        if out.contains("WAITING") { return "WAITING" }
        if out.contains("DONE") { return "DONE" }
        if out.contains("ACTIVE") { return "ACTIVE" }
        return Recommender.heuristicState(lastText: msg)
    }

    /// Resolve the `claude` binary. GUI/launchd apps get a minimal PATH, so we
    /// check known locations, then fall back to a login shell lookup.
    private static func claudePath() -> String? {
        if let override = ProcessInfo.processInfo.environment["GCB_CLAUDE"],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let found = run("/bin/zsh", ["-lc", "command -v claude"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !found.isEmpty,
           FileManager.default.isExecutableFile(atPath: found) {
            return found
        }
        return nil
    }

    private static func run(_ launch: String, _ args: [String], env: [String: String]? = nil, registerPID: Bool = false) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launch)
        process.arguments = args
        if let env { process.environment = env }
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }

        let pid = Int(process.processIdentifier)
        if registerPID { IgnoredPIDs.shared.add(pid) }
        defer { if registerPID { IgnoredPIDs.shared.remove(pid) } }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
