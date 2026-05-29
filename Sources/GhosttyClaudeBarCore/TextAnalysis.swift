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
}
// Transcript fingerprint, last-assistant text, and usage are now computed in a
// single pass — see `Transcript.scan`.
