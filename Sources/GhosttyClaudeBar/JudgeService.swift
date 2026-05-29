import Foundation
import GhosttyClaudeBarCore

/// Watches for verdict sidecars flagged `needsJudge` (written instantly by the
/// Stop hook) and refines them with Haiku off the main thread, then triggers a
/// UI refresh. One judge per (session, turn); never re-judges the same turn.
@MainActor
final class JudgeService {
    private var inFlight = Set<String>()
    private let onUpdated: () -> Void

    init(onUpdated: @escaping () -> Void) {
        self.onUpdated = onUpdated
    }

    /// Cheap: lists `*.state`, dispatches Haiku for any pending, un-judged turn.
    /// Called after each refresh (so an FSEvents-delivered sidecar gets picked up).
    func scan() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: Paths.sessionsDir) else { return }

        for file in files where file.hasSuffix(".state") {
            let sid = String(file.dropLast(6))
            guard !inFlight.contains(sid),
                  let d = VerdictStore.read(sessionId: sid),
                  d["needsJudge"] as? Bool == true
            else { continue }

            let last = d["lastMessage"] as? String
            let ts = (d["ts"] as? Double) ?? Date().timeIntervalSince1970
            inFlight.insert(sid)

            Task.detached(priority: .utility) {
                let state = Judge.classify(lastMessage: last)
                await MainActor.run {
                    VerdictStore.write(sessionId: sid, state: state, ts: ts,
                                       lastMessage: last, needsJudge: false)
                    self.inFlight.remove(sid)
                    self.onUpdated()
                }
            }
        }
    }
}
