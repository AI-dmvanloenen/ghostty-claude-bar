import AppKit
import GhosttyClaudeBarCore

/// Prompts for a folder, then opens a new Ghostty window running `claude` there.
@MainActor
enum SessionLauncher {
    static func promptAndLaunch() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Claude here"
        panel.message = "Choose a folder for the new Claude Code session"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path
        Task.detached { GhosttyClient.newSession(directory: path) }
    }
}
