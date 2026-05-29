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
        if session.status == "busy" {
            return Verdict(state: .working, reason: "busy — working now")
        }

        let ageH = session.ageHours(now: now)
        let age = fmtAge(ageH)

        // Stop-hook verdict — a model judged the final turn.
        switch readStopVerdict(sessionId: session.sessionId) {
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

    /// Model-judged state from the Stop-hook sidecar `<sessionId>.state`.
    static func readStopVerdict(sessionId: String) -> String? {
        guard !sessionId.isEmpty else { return nil }
        let path = "\(Paths.sessionsDir)/\(sessionId).state"
        guard let data = FileManager.default.contents(atPath: path),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return d["state"] as? String
    }

    public static func fmtAge(_ hours: Double) -> String {
        if hours < 1 { return "\(Int(hours * 60))m" }
        if hours < 24 { return String(format: "%.1fh", hours) }
        return String(format: "%.1fd", hours / 24)
    }
}
