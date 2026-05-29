import Foundation

/// Token + cost accounting for a session transcript, ported from the Python tool.
///
/// Cache reads bill ~1/10th of fresh input and cache writes ~25% more, so you
/// cannot sum tokens against a single rate. An unknown model yields a nil cost
/// (rendered "~$?") rather than a wrong guess.
public enum Usage {
    struct Rates { let input, cacheWrite, cacheRead, output: Double }

    /// USD per 1M tokens, matched by substring against `message.model`.
    static let prices: [(key: String, rates: Rates)] = [
        ("opus",   Rates(input: 15.0, cacheWrite: 18.75, cacheRead: 1.5, output: 75.0)),
        ("sonnet", Rates(input: 3.0,  cacheWrite: 3.75,  cacheRead: 0.3, output: 15.0)),
        ("haiku",  Rates(input: 1.0,  cacheWrite: 1.25,  cacheRead: 0.1, output: 5.0)),
    ]

    public struct Summary: Sendable {
        public let tokens: Int
        public let cost: Double?   // nil if any turn used an unpriced model
        public let unknown: Bool   // at least one turn couldn't be priced
    }

    private static func rates(for model: String?) -> Rates? {
        guard let model else { return nil }
        return prices.first { model.contains($0.key) }?.rates
    }

    /// Sum billable tokens + USD cost across all assistant turns.
    public static func summarize(jsonlPath: String?) -> Summary {
        guard let jsonlPath, let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else {
            return Summary(tokens: 0, cost: nil, unknown: false)
        }
        var tokens = 0
        var cost = 0.0
        var unknown = false

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  d["type"] as? String == "assistant",
                  let msg = d["message"] as? [String: Any]
            else { continue }

            let u = msg["usage"] as? [String: Any] ?? [:]
            let inp = intVal(u["input_tokens"])
            let cw = intVal(u["cache_creation_input_tokens"])
            let cr = intVal(u["cache_read_input_tokens"])
            let out = intVal(u["output_tokens"])
            tokens += inp + cw + cr + out

            guard let r = rates(for: msg["model"] as? String) else {
                if inp + cw + cr + out > 0 { unknown = true }
                continue
            }
            cost += (Double(inp) * r.input
                     + Double(cw) * r.cacheWrite
                     + Double(cr) * r.cacheRead
                     + Double(out) * r.output) / 1_000_000
        }
        return Summary(tokens: tokens, cost: unknown ? cost : cost, unknown: unknown)
    }

    public static func fmtTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }

    public static func fmtCost(_ s: Summary) -> String {
        guard let c = s.cost, !(s.unknown && c == 0) else { return "~$?" }
        let prefix = s.unknown ? "~$" : "$"
        return prefix + String(format: "%.2f", c)
    }

    private static func intVal(_ v: Any?) -> Int {
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let d = v as? Double { return Int(d) }
        return 0
    }
}
