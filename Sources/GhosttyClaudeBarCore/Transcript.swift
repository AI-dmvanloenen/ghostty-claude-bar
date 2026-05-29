import Foundation

/// Everything we need from a session transcript, computed in a SINGLE forward
/// pass over the file. Previously the matcher (fingerprint), the row builder
/// (last assistant message) and the cost column (usage) each read and re-parsed
/// the whole `.jsonl` — three reads per session, which made the menu sluggish on
/// large transcripts. This reads once.
public struct TranscriptScan: Sendable {
    public let fingerprint: String
    public let lastAssistantText: String?
    public let usage: Usage.Summary
}

public enum Transcript {
    public static func scan(path: String?, cwd: String) -> TranscriptScan {
        var fingerprintParts = [cwd.lowercased()]
        var lastText: String?
        var tokens = 0
        var cost = 0.0
        var unknown = false

        if let path, let content = try? String(contentsOfFile: path, encoding: .utf8) {
            for (i, line) in content.split(separator: "\n", omittingEmptySubsequences: true).enumerated() {
                guard let data = line.data(using: .utf8),
                      let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                switch d["type"] as? String {
                case "user":
                    if i <= 500 {
                        let text = TextAnalysis.messageText(d["message"])
                        if !text.isEmpty, !text.hasPrefix("[tool:") {
                            fingerprintParts.append(String(text.prefix(400)).lowercased())
                        }
                    }
                case "assistant":
                    let text = TextAnalysis.messageText(d["message"])
                    if !text.isEmpty, !text.hasPrefix("[tool:") {
                        if i <= 500 { fingerprintParts.append(String(text.prefix(200)).lowercased()) }
                        lastText = text // keep the latest readable assistant message
                    }
                    if let msg = d["message"] as? [String: Any] {
                        let line = Usage.lineCost(message: msg)
                        tokens += line.tokens
                        if let c = line.cost {
                            cost += c
                        } else if line.tokens > 0 {
                            unknown = true
                        }
                    }
                default:
                    break
                }
            }
        }

        return TranscriptScan(
            fingerprint: fingerprintParts.joined(separator: " "),
            lastAssistantText: lastText,
            usage: Usage.Summary(tokens: tokens, cost: cost, unknown: unknown)
        )
    }
}
