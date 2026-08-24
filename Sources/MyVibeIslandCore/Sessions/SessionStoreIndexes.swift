public struct SessionStoreIndexes: Equatable, Sendable {
    public let activeSessionId: String?
    public let summarizedSessionIds: [String]
    public let questionSelections: [String: String]

    public init(
        activeSessionId: String? = nil,
        summarizedSessionIds: [String] = [],
        questionSelections: [String: String] = [:]
    ) {
        self.activeSessionId = activeSessionId
        self.summarizedSessionIds = summarizedSessionIds
        self.questionSelections = questionSelections
    }

    public init(snapshot: SessionStoreSnapshot) {
        self.init(
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        )
    }
}
