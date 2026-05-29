import Foundation
import GhosttyClaudeBarCore

/// Asks Haiku for a concise title that matches a session's content, for the
/// "fix name" action (which then sends `/rename <title>` into the session).
enum NameSuggester {
    static func suggest(sessionId: String, displayCwd: String) -> String? {
        let cwd = Paths.expandHome(displayCwd)
        guard let path = Paths.transcriptPath(sessionId: sessionId, cwd: cwd) else { return nil }
        let content = String(Transcript.scan(path: path, cwd: cwd).fingerprint.prefix(3500))
        guard content.count > 20 else { return nil }

        let prompt = """
        Generate a concise, specific title for this coding session — 3 to 6 words, Title Case, \
        no quotes, no trailing punctuation. It should capture what the session is actually about. \
        Reply with ONLY the title.

        Session content:
        \(content)
        """

        guard let out = ClaudeCLI.run(prompt) else { return nil }
        let title = (out.split(separator: "\n").first.map(String.init) ?? out)
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : String(title.prefix(60))
    }
}
