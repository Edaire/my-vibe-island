import Foundation

public struct UsagePresentationSnapshot: Codable, Equatable, Sendable {
    public let selection: UsageProviderSelection
    public let displayState: UsageDisplayState
    public let peekIntents: [UsagePeekIntent]
    public let cachedSnapshot: UsageSnapshot?
    public let resetPeekSchedulePlan: UsageResetPeekSchedulePlan
    public let notificationPayloads: [UsagePeekNotificationPayload]
    public let notificationDeliveryPlan: UsageNotificationDeliveryPlan
    public let diagnosticSummary: UsageProviderDiagnosticSummary?
    public let selectedRefreshPlanEntry: UsageRefreshPlanEntry?
    public let selectedAccountRecord: UsageAccountRecord?

    public init(
        selection: UsageProviderSelection,
        displayState: UsageDisplayState,
        peekIntents: [UsagePeekIntent] = [],
        cachedSnapshot: UsageSnapshot? = nil,
        resetPeekSchedulePlan: UsageResetPeekSchedulePlan = UsageResetPeekSchedulePlan(actions: []),
        notificationPayloads: [UsagePeekNotificationPayload] = [],
        notificationDeliveryPlan: UsageNotificationDeliveryPlan = UsageNotificationDeliveryPlan(actions: []),
        diagnosticSummary: UsageProviderDiagnosticSummary? = nil,
        selectedRefreshPlanEntry: UsageRefreshPlanEntry? = nil,
        selectedAccountRecord: UsageAccountRecord? = nil
    ) {
        self.selection = selection
        self.displayState = displayState
        self.peekIntents = peekIntents
        self.cachedSnapshot = cachedSnapshot
        self.resetPeekSchedulePlan = resetPeekSchedulePlan
        self.notificationPayloads = notificationPayloads
        self.notificationDeliveryPlan = notificationDeliveryPlan
        self.diagnosticSummary = diagnosticSummary
        self.selectedRefreshPlanEntry = selectedRefreshPlanEntry
        self.selectedAccountRecord = selectedAccountRecord
    }
}
