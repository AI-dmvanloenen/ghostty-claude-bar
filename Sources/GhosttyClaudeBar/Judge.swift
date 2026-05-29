import Foundation
import GhosttyClaudeBarCore

/// Classifies a finished turn as DONE / WAITING / ACTIVE via Haiku, falling back
/// to the heuristic if the CLI is unavailable.
enum Judge {
    static func classify(lastMessage: String?) -> String {
        guard let msg = lastMessage, !msg.isEmpty else { return "ACTIVE" }

        let prompt = """
        Classify the assistant's final message in a coding session. Reply with EXACTLY one word, nothing else.
        WAITING — it asks the user anything, requests a decision/permission/input, or offers options for the user to pick. A question addressed to the user means WAITING.
        DONE — the task is finished with nothing left for the user to do.
        ACTIVE — it is narrating in-progress work it will continue on its own, no user input needed.

        Message:
        \(String(msg.prefix(4000)))
        """

        let out = (ClaudeCLI.run(prompt) ?? "").uppercased()
        if out.contains("WAITING") { return "WAITING" }
        if out.contains("DONE") { return "DONE" }
        if out.contains("ACTIVE") { return "ACTIVE" }
        return Recommender.heuristicState(lastText: msg)
    }
}
