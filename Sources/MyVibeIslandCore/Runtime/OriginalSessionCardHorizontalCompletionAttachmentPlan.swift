struct OriginalSessionCardHorizontalCompletionAttachmentPlan: Equatable, Sendable {
    enum AttachmentKind: Equatable, Sendable {
        case completionUnreadDot
        case ageTag(String)
    }

    let kind: AttachmentKind
    let contentOpacity: Double

    static func resolve(
        cardID: String,
        unreadCompletedIDs: Set<String>,
        ageLabel: String,
        interactionStateA: Bool
    ) -> Self {
        Self(
            kind: unreadCompletedIDs.contains(cardID)
                ? .completionUnreadDot
                : .ageTag(ageLabel),
            contentOpacity: interactionStateA ? 0.0 : 1.0
        )
    }
}
