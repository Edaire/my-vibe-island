import Foundation

public struct DiagnosticRedactor: Sendable {
    public let policy: RedactionPolicy

    public init(policy: RedactionPolicy = .default) {
        self.policy = policy
    }

    public func redactText(_ text: String) -> String {
        var redacted = redactHomePaths(in: text)
        redacted = redactAssignments(in: redacted, keys: ["credential", "session_token", "token", "secret"])
        return redacted
    }

    public func redactFields(
        _ fields: [String: String],
        forbiddenFields: [String]
    ) -> [String: String] {
        let forbidden = Set(forbiddenFields.map { $0.lowercased() })

        return fields.reduce(into: [:]) { result, entry in
            if forbidden.contains(entry.key.lowercased()) || policy.shouldRedactField(named: entry.key) {
                result[entry.key] = "<redacted>"
            } else {
                result[entry.key] = redactText(entry.value)
            }
        }
    }

    public func redactFields(_ fields: [String: String]) -> [String: String] {
        redactFields(fields, forbiddenFields: [])
    }

    private func redactHomePaths(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"/Users/([^/\s]+)"#) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "/Users/<user>"
        )
    }

    private func redactAssignments(in text: String, keys: [String]) -> String {
        let escapedKeys = keys.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\b("# + escapedKeys + #")\b(\s*[:=]\s*)([^\s,;]+)"#
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "$1$2<redacted>"
        )
    }
}
