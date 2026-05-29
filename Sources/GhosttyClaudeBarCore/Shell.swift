import Foundation

/// Minimal process runner. Used for `ps` and `osascript` — keeps Core free of
/// any AppKit dependency so it stays unit-testable.
enum Shell {
    /// Run a tool with args, optionally feeding stdin. Returns stdout as a string,
    /// or nil on launch failure. Best-effort: errors are swallowed (matches the
    /// Python tool's defensive try/except around osascript).
    @discardableResult
    static func run(_ launchPath: String, _ args: [String], stdin: String? = nil, timeout: TimeInterval = 8) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        let inPipe = Pipe()
        if stdin != nil { process.standardInput = inPipe }

        do {
            try process.run()
        } catch {
            return nil
        }

        if let stdin, let data = stdin.data(using: .utf8) {
            inPipe.fileHandleForWriting.write(data)
            try? inPipe.fileHandleForWriting.close()
        }

        // Watchdog: terminate if it overruns, so a hung osascript / claude can't
        // freeze the refresh loop. Our outputs are tiny (well under the pipe
        // buffer), so polling-then-reading is safe.
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning { process.terminate() }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
