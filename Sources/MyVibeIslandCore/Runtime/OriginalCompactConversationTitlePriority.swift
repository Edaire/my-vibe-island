public enum OriginalCompactConversationTitlePriority {
    public static func resolve(
        customTitle: String?,
        desktopTitle: String?,
        aiTitle: String?,
        summary: String?,
        normalizedFirstUserMessage: String?,
        normalizedLastUserMessage: String?
    ) -> String? {
        [
            customTitle,
            desktopTitle,
            aiTitle,
            summary,
            normalizedFirstUserMessage,
            normalizedLastUserMessage,
        ].compactMap { $0 }.first(where: { !$0.isEmpty })
    }
}
