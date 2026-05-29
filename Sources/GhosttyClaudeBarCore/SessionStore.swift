import Foundation

/// Loads live Claude Code sessions from `~/.claude/sessions/*.json`.
public enum SessionStore {
    /// PIDs currently alive (`ps -axo pid=`).
    static func livePIDs() -> Set<Int> {
        let out = Shell.run("/bin/ps", ["-axo", "pid="]) ?? ""
        var pids = Set<Int>()
        for line in out.split(separator: "\n") {
            if let pid = Int(line.trimmingCharacters(in: .whitespaces)) {
                pids.insert(pid)
            }
        }
        return pids
    }

    /// All sessions whose owning PID is still alive, sorted by start time.
    public static func load() -> [Session] {
        let live = livePIDs()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: Paths.sessionsDir) else {
            return []
        }

        var sessions: [Session] = []
        for file in files where file.hasSuffix(".json") {
            let pidStem = String(file.dropLast(5))
            guard let pid = Int(pidStem), live.contains(pid),
                  !IgnoredPIDs.shared.contains(pid) // skip the judge's own claude -p
            else { continue }
            let path = "\(Paths.sessionsDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            sessions.append(Session(
                pid: pid,
                sessionId: d["sessionId"] as? String ?? "",
                cwd: d["cwd"] as? String ?? "",
                status: d["status"] as? String,
                startedAt: asDouble(d["startedAt"]),
                updatedAt: asDouble(d["updatedAt"])
            ))
        }
        sessions.sort { $0.startedAt < $1.startedAt }

        sweepOrphanVerdicts(liveSessionIds: Set(sessions.map(\.sessionId)))
        return sessions
    }

    /// Remove Stop-hook verdict sidecars (`<sessionId>.state`) whose session is gone.
    private static func sweepOrphanVerdicts(liveSessionIds: Set<String>) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: Paths.sessionsDir) else { return }
        for file in files where file.hasSuffix(".state") {
            let sid = String(file.dropLast(6))
            if !liveSessionIds.contains(sid) {
                try? fm.removeItem(atPath: "\(Paths.sessionsDir)/\(file)")
            }
        }
    }

    private static func asDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String, let d = Double(s) { return d }
        return 0
    }
}
