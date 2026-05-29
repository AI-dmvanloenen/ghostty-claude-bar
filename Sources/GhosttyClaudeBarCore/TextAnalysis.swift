import Foundation

/// Text utilities ported from the Python tool: title-keyword extraction, message
/// flattening, and the session fingerprint used for window↔session matching.
enum TextAnalysis {
    static let stopwords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "are", "was", "but",
        "not", "you", "your", "all", "any", "can", "use", "via", "into", "out",
        "new", "old", "one", "two",
    ]

    /// Strip Claude Code's leading status glyph(s) / punctuation from a title.
    /// (Python's TITLE_ICON_RE — here we just drop leading non-alphanumerics,
    /// which covers the braille spinners, ✳, whitespace, and punctuation.)
    static func stripLeadingGlyphs(_ title: String) -> String {
        var s = Substring(title)
        while let first = s.first, !first.isLetter, !first.isNumber {
            s = s.dropFirst()
        }
        return String(s)
    }

    /// Keywords from a tab title: word-ish tokens (start with a letter, length ≥ 3),
    /// lowercased, minus stopwords.
    static func titleKeywords(_ title: String) -> [String] {
        let stripped = stripLeadingGlyphs(title)
        var words: [String] = []
        var current = ""
        func flush() {
            if let first = current.first, first.isLetter, current.count >= 3 {
                let lower = current.lowercased()
                if !stopwords.contains(lower) { words.append(lower) }
            }
            current = ""
        }
        for ch in stripped {
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
                current.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return words
    }

    /// Flatten a transcript `message.content` (string, or array of text/tool_use
    /// blocks) into readable text. Tool calls become `[tool:name]`.
    static func messageText(_ message: Any?) -> String {
        let content: Any?
        if let dict = message as? [String: Any] {
            content = dict["content"]
        } else {
            content = message
        }
        if let list = content as? [Any] {
            var parts: [String] = []
            for c in list {
                if let block = c as? [String: Any] {
                    switch block["type"] as? String {
                    case "text":
                        if let t = block["text"] as? String { parts.append(t) }
                    case "tool_use":
                        parts.append("[tool:\(block["name"] as? String ?? "?")]")
                    default:
                        break
                    }
                } else {
                    parts.append("\(c)")
                }
            }
            return parts.filter { !$0.isEmpty }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = content as? String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    /// Concatenated lowercased text of user messages (first 400 chars each) +
    /// assistant messages (first 200) + cwd, for the first ~500 transcript lines.
    static func fingerprint(jsonlPath: String?, cwd: String) -> String {
        var parts = [cwd.lowercased()]
        guard let jsonlPath, let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else {
            return parts.joined(separator: " ")
        }
        for (i, line) in content.split(separator: "\n", omittingEmptySubsequences: true).enumerated() {
            if i > 500 { break }
            guard let data = line.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let type = d["type"] as? String
            if type == "user" {
                let text = messageText(d["message"])
                if !text.isEmpty, !text.hasPrefix("[tool:") {
                    parts.append(String(text.prefix(400)).lowercased())
                }
            } else if type == "assistant" {
                let text = messageText(d["message"])
                if !text.isEmpty, !text.hasPrefix("[tool:") {
                    parts.append(String(text.prefix(200)).lowercased())
                }
            }
        }
        return parts.joined(separator: " ")
    }

    /// Last assistant message with readable (non-tool) text. Returns nil if none.
    static func lastAssistantText(jsonlPath: String?) -> String? {
        guard let jsonlPath, let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else {
            return nil
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  d["type"] as? String == "assistant"
            else { continue }
            let text = messageText(d["message"])
            if !text.isEmpty, !text.hasPrefix("[tool:") {
                return text
            }
        }
        return nil
    }
}
