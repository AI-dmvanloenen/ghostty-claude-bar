import Foundation

/// Decides a session's `SessionState` + a human reason, porting the Python
/// `recommend()`. Order matters: `busy` always wins, then the model-judged Stop
/// verdict, then heuristics on the last assistant message + idle age.
public enum Recommender {
    static let questionHints = [
        "want me to", "should i", "shall i", "do you want",
        "let me know", "which one", "ready to proceed",
    ]
    static let doneHints = [
        "done.", "complete.", "finished.", "all set", "summary:", "wrapped up",
    ]

    public struct Verdict { public let state: SessionState; public let reason: String }

    public static func recommend(session: Session, lastText: String?, now: Date) -> Verdict {
        let ageH = session.ageHours(now: now)
        let age = fmtAge(ageH)
        let hookVerdict = readVerdict(sessionId: session.sessionId)

        if session.status == "busy" {
            // A fresh "waiting" event (Notification hook) means Claude is blocked
            // on YOU mid-turn (e.g. a permission prompt) — that wins over busy.
            // Stale once work resumes (session.updatedAt moves past the verdict).
            if let v = hookVerdict, v.state == "WAITING",
               v.ts >= session.updatedAt / 1000 - 2 {
                return Verdict(state: .needsReply, reason: "waiting on you · needs input")
            }
            return Verdict(state: .working, reason: "busy — working now")
        }

        // Stop-hook verdict — a model judged the final turn.
        switch hookVerdict?.state {
        case "DONE":
            return Verdict(state: .safeToClose, reason: "done — Claude judged complete · idle \(age)")
        case "WAITING" where ageH <= 24:
            return Verdict(state: .needsReply, reason: "waiting on you · \(age) idle")
        default:
            break
        }

        guard let lastText, !lastText.isEmpty else {
            return Verdict(state: .idle, reason: "no readable activity")
        }

        let lower = lastText.lowercased()
        let endsQ = lastText.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?")
        let hintQ = questionHints.contains { lower.contains($0) }
        let hintDone = doneHints.contains { lower.contains($0) }

        if endsQ || hintQ {
            return Verdict(state: .needsReply, reason: "waiting on you · \(age) idle")
        }
        if ageH < 0.5 {
            return Verdict(state: .idle, reason: "active \(age) ago")
        }
        if ageH > 24 {
            let verdict = (hintDone || ageH > 72) ? "safe to close" : "likely safe"
            return Verdict(state: .safeToClose, reason: "idle \(age) — \(verdict)")
        }
        if ageH > 4 && hintDone {
            return Verdict(state: .safeToClose, reason: "idle \(age) — done")
        }
        return Verdict(state: .idle, reason: "idle \(age)")
    }

    public struct HookVerdict { public let state: String; public let ts: Double }

    /// Verdict from the hook sidecar `<sessionId>.state` (`{state, ts}`, ts in
    /// epoch seconds). Written by the Stop hook (done/waiting at turn end) or the
    /// Notification hook (waiting-on-you mid-turn).
    static func readVerdict(sessionId: String) -> HookVerdict? {
        guard !sessionId.isEmpty else { return nil }
        let path = "\(Paths.sessionsDir)/\(sessionId).state"
        guard let data = FileManager.default.contents(atPath: path),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = d["state"] as? String
        else { return nil }
        let ts = (d["ts"] as? Double) ?? (d["ts"] as? NSNumber)?.doubleValue ?? 0
        return HookVerdict(state: state, ts: ts)
    }

    /// Instant, model-free classification of a finished turn from its last
    /// assistant message — the placeholder shown the moment a turn ends, before
    /// the Haiku judge refines it. Returns "DONE" / "WAITING" / "ACTIVE".
    public static func heuristicState(lastText: String?) -> String {
        guard let t = lastText, !t.isEmpty else { return "ACTIVE" }
        let lower = t.lowercased()
        if t.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?")
            || questionHints.contains(where: { lower.contains($0) }) {
            return "WAITING"
        }
        if doneHints.contains(where: { lower.contains($0) }) { return "DONE" }
        return "ACTIVE"
    }

    public static func fmtAge(_ hours: Double) -> String {
        if hours < 1 { return "\(Int(hours * 60))m" }
        if hours < 24 { return String(format: "%.1fh", hours) }
        return String(format: "%.1fd", hours / 24)
    }
}
