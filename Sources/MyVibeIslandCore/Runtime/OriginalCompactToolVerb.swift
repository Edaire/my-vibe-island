public enum OriginalCompactToolVerb {
    public enum Resolution: Equatable, Sendable {
        case localized(key: String, englishFallback: String)
        case verbatim(String)
    }

    public static func resolve(_ tool: String) -> Resolution {
        switch tool {
        case "Edit":
            .localized(key: "tool.editing", englishFallback: "Editing")
        case "Read":
            .localized(key: "tool.reading", englishFallback: "Reading")
        case "Write":
            .localized(key: "tool.writing", englishFallback: "Writing")
        case "Bash":
            .localized(key: "tool.running", englishFallback: "Running")
        case "Grep":
            .localized(key: "tool.searching", englishFallback: "Searching")
        case "Glob":
            .localized(key: "tool.finding", englishFallback: "Finding")
        case "Task":
            .localized(key: "tool.tasking", englishFallback: "Tasking")
        case "WebFetch":
            .localized(key: "tool.fetching", englishFallback: "Fetching")
        case "WebSearch":
            .localized(key: "tool.searching", englishFallback: "Searching")
        default:
            .verbatim(tool)
        }
    }
}
