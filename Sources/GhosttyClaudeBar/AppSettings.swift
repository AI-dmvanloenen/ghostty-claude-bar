import Foundation

/// Lightweight persisted preferences (UserDefaults).
enum AppSettings {
    static let refreshOptions: [(label: String, seconds: TimeInterval)] = [
        ("10 seconds", 10), ("30 seconds", 30), ("1 minute", 60), ("5 minutes", 300),
    ]

    static var refreshInterval: TimeInterval {
        get {
            let v = UserDefaults.standard.double(forKey: "refreshInterval")
            return v > 0 ? v : 30
        }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval") }
    }
}
