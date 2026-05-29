import Foundation

/// Reads/writes the per-session verdict sidecar `~/.claude/sessions/<sid>.state`.
/// Shared by the hooks (which write) and the app's judge service (which reads the
/// pending flag, then rewrites with the model verdict). Format:
/// `{ "state": "DONE|WAITING|ACTIVE", "ts": <epoch secs>, "needsJudge": Bool,
///    "lastMessage": String? }`
public enum VerdictStore {
    public static func path(for sessionId: String) -> String {
        "\(Paths.sessionsDir)/\(sessionId).state"
    }

    public static func write(
        sessionId: String,
        state: String,
        ts: Double,
        lastMessage: String? = nil,
        needsJudge: Bool = false
    ) {
        guard !sessionId.isEmpty else { return }
        var dict: [String: Any] = ["state": state, "ts": ts, "needsJudge": needsJudge]
        if let lastMessage { dict["lastMessage"] = lastMessage }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? data.write(to: URL(fileURLWithPath: path(for: sessionId)))
    }

    public static func read(sessionId: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path(for: sessionId)),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return d
    }
}
