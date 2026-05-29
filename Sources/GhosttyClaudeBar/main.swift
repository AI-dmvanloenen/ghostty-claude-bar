import AppKit

// Menu-bar agent app. `.accessory` keeps it out of the Dock and the app
// switcher even when launched via `swift run` (no bundle / Info.plist needed
// for dev — the packaged .app sets LSUIElement in Phase 5).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
