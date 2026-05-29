import Foundation

/// PIDs to exclude from the session list. The Haiku judge spawns a headless
/// `claude -p` process, which (as of current Claude Code) DOES create a transient
/// `~/.claude/sessions/<pid>.json` for ~7s — that would flicker into the UI as a
/// phantom "ghost" row. The judge registers its spawned PID here so the collector
/// skips it. Thread-safe; shared across the detached collect + judge tasks.
public final class IgnoredPIDs: @unchecked Sendable {
    public static let shared = IgnoredPIDs()

    private let lock = NSLock()
    private var pids = Set<Int>()

    public func add(_ pid: Int) { lock.lock(); pids.insert(pid); lock.unlock() }
    public func remove(_ pid: Int) { lock.lock(); pids.remove(pid); lock.unlock() }
    public func contains(_ pid: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return pids.contains(pid)
    }
}
