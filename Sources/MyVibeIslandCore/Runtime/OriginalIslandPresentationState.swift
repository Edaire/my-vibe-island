public struct OriginalIslandPresentationState: Codable, Equatable, Sendable {
    public let geometryRole: OriginalIslandDisplayState
    public let contentReason: PanelDisplayState

    public init(_ contentReason: PanelDisplayState) {
        self.contentReason = contentReason
        switch contentReason {
        case .closed, .opening, .hidden, .autoHidden:
            geometryRole = .compact
        case .notificationPeek:
            geometryRole = .peek
        case .expanded, .switcher, .onboarding:
            geometryRole = .expanded
        }
    }
}
