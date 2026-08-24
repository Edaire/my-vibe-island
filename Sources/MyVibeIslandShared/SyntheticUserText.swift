public enum SyntheticUserText {
    public static let prefixes: [String] = [
        "# AGENTS.md instructions for ",
        "<environment_context>",
        "<permissions instructions>",
        "<collaboration_mode>",
        "<skills_instructions>",
        "<codex_internal_context",
        "<subagent_notification>",
    ]

    public static func isSynthetic(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefixes.contains { trimmed.hasPrefix($0) }
    }

    public static func unwrappedUserQuery(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["User query:", "User message:", "用户问题：", "用户问题:"] {
            guard trimmed.hasPrefix(prefix) else { continue }
            let value = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return isSynthetic(trimmed) ? nil : trimmed
    }
}
