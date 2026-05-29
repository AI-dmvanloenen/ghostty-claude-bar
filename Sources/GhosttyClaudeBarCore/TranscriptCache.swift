import Foundation

/// Caches transcript scans keyed on the file's modification time + size, so a
/// refresh only re-reads transcripts that actually changed. During an active
/// turn that's a single file instead of every session's full `.jsonl` — the
/// main lever for "low overhead". Shared across collects (static instance).
public final class TranscriptCache: @unchecked Sendable {
    public static let shared = TranscriptCache()

    private struct Entry {
        let mtime: TimeInterval
        let size: Int
        let scan: TranscriptScan
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    public func scan(path: String?, cwd: String) -> TranscriptScan {
        guard let path else { return Transcript.scan(path: nil, cwd: cwd) }

        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs?[.size] as? Int) ?? 0

        lock.lock()
        if let e = entries[path], e.mtime == mtime, e.size == size {
            lock.unlock()
            return e.scan
        }
        lock.unlock()

        // Compute outside the lock so a slow read doesn't block other sessions.
        let scan = Transcript.scan(path: path, cwd: cwd)

        lock.lock()
        entries[path] = Entry(mtime: mtime, size: size, scan: scan)
        lock.unlock()
        return scan
    }

    /// Drop cache entries for files that no longer exist (closed sessions).
    public func prune(livePaths: Set<String>) {
        lock.lock()
        entries = entries.filter { livePaths.contains($0.key) }
        lock.unlock()
    }
}
