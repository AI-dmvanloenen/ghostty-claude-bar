import Foundation
import GhosttyClaudeBarCore

/// Runs when the app binary is invoked as a Claude Code hook (`--stop-hook` /
/// `--notify-hook`). Reads the hook payload on stdin, writes a verdict sidecar,
/// and exits immediately — it never calls a model, so it never delays your
/// session. The long-running app picks up the sidecar (FSEvents) and refines
/// the Stop verdict with Haiku.
enum HookRunner {
    static func runStopHook() {
        // Recursion guard: when WE call `claude` to judge, that session's Stop
        // hook fires this same binary — bail so we don't loop.
        if ProcessInfo.processInfo.environment["GCB_JUDGE"] != nil { return }

        let json = readPayload()
        guard let sid = json["session_id"] as? String, !sid.isEmpty else { return }
        if json["stop_hook_active"] as? Bool == true { return }

        var last = json["last_assistant_message"] as? String
        if (last?.isEmpty ?? true), let transcript = json["transcript_path"] as? String {
            last = Transcript.scan(path: transcript, cwd: "").lastAssistantText
        }

        // Instant heuristic verdict, flagged for the app to refine with Haiku.
        let state = Recommender.heuristicState(lastText: last)
        VerdictStore.write(sessionId: sid, state: state, ts: Date().timeIntervalSince1970,
                           lastMessage: last, needsJudge: true)
    }

    static func runNotificationHook() {
        let json = readPayload()
        guard let sid = json["session_id"] as? String, !sid.isEmpty else { return }
        // Notification = Claude is blocked on you (permission / input). No model
        // needed — this is already the precise "needs reply" signal.
        VerdictStore.write(sessionId: sid, state: "WAITING", ts: Date().timeIntervalSince1970,
                           needsJudge: false)
    }

    private static func readPayload() -> [String: Any] {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
