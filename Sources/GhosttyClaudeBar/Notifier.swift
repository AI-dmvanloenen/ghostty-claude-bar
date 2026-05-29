import Foundation

/// Posts macOS notifications. Uses `osascript display notification` because the
/// dev binary has no bundle identifier (UNUserNotificationCenter requires one and
/// would crash). The packaged .app can switch to UserNotifications later for
/// clickable / branded notifications.
enum Notifier {
    static func post(title: String, subtitle: String) {
        let script = "display notification \"\(esc(subtitle))\" with title \"Ghostty Claude Bar\" subtitle \"\(esc(title))\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardError = Pipe()
        try? process.run()
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
