public struct StatuslinePanelPromptPlan: Codable, Equatable, Sendable {
    public let sourceId: String
    public let templateId: String
    public let placeholderKeys: [String]
    public let isEnabled: Bool

    public var diagnosticSummary: StatuslinePanelPromptDiagnosticSummary {
        StatuslinePanelPromptDiagnosticSummary(plan: self)
    }

    public init(
        sourceId: String,
        templateId: String,
        placeholderKeys: [String],
        isEnabled: Bool
    ) {
        self.sourceId = sourceId
        self.templateId = templateId
        self.placeholderKeys = Array(Set(placeholderKeys)).sorted()
        self.isEnabled = isEnabled
    }
}

public struct StatuslinePanelPromptDiagnosticSummary: Codable, Equatable, Sendable {
    public let placeholderCount: Int
    public let isEnabled: Bool

    public init(plan: StatuslinePanelPromptPlan) {
        placeholderCount = plan.placeholderKeys.count
        isEnabled = plan.isEnabled
    }
}
