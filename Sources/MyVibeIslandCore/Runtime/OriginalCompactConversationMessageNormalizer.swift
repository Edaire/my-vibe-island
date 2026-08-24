import Foundation

public enum OriginalCompactConversationMessageNormalizer {
    public static func resolve(_ input: String) -> String? {
        guard input.drop(while: \.isWhitespace).hasPrefix("codex_desktop_thread") else {
            return input
        }

        let closingTags = [
            "</session_state>",
            "</sources>",
            "</workspace_capabilities>",
            "</working_directory>",
            "</working_directory_context>",
        ]
        guard let end = closingTags.compactMap({
            input.range(of: $0, options: .backwards)?.upperBound
        }).max() else {
            return nil
        }

        return input[end...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
