public struct SessionStorePublishState: Codable, Equatable, Sendable {
    public let silenceSnapshot: SilenceRulesSnapshot?
    public let isPublishScheduled: Bool

    public var diagnosticSummary: SessionStorePublishSummary {
        SessionStorePublishSummary(state: self)
    }

    public init(
        silenceSnapshot: SilenceRulesSnapshot? = nil,
        isPublishScheduled: Bool = false
    ) {
        self.silenceSnapshot = silenceSnapshot
        self.isPublishScheduled = isPublishScheduled
    }
}

public struct SessionStorePublishSummary: Codable, Equatable, Sendable {
    public let hasSilenceSnapshot: Bool
    public let isPublishScheduled: Bool
    public let disabledBuiltInRuleCount: Int
    public let customSilenceRuleCount: Int

    public init(state: SessionStorePublishState) {
        hasSilenceSnapshot = state.silenceSnapshot != nil
        isPublishScheduled = state.isPublishScheduled
        disabledBuiltInRuleCount = state.silenceSnapshot?.disabledBuiltInIds.count ?? 0
        customSilenceRuleCount = state.silenceSnapshot?.customRules.count ?? 0
    }
}
