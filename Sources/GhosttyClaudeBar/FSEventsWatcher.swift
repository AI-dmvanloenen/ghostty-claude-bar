import CoreServices
import Foundation

/// Watches a directory tree with FSEvents and fires a debounced callback on the
/// main queue. We watch `~/.claude/sessions/` so the menu bar reacts the moment
/// a session starts/stops, a status flips busy↔idle, or the Stop hook drops a
/// verdict sidecar — no polling.
///
/// FSEvents is FSEvents-backed (fires on in-place writes too, with a few hundred
/// ms of coalescing latency), and session files churn during an active turn, so
/// we debounce on top to avoid spawning AppleScript on every write.
final class FSEventsWatcher {
    private let path: String
    private let onChange: @Sendable () -> Void
    private var stream: FSEventStreamRef?
    private var debounce: DispatchWorkItem?

    init(path: String, onChange: @escaping @Sendable () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Non-capturing C callback → recover `self` from the info pointer.
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue().fired()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency: built-in coalescing
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    /// Called on the main queue (we set the dispatch queue above). Debounce a
    /// further 600ms so a burst of session-file writes collapses to one refresh.
    private func fired() {
        debounce?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
