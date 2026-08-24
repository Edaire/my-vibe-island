import Foundation

public enum OnboardingReadyNextAction: String, Codable, Equatable, Sendable {
    case startUsing
    case openSettings
    case restartApp
    case startDemo
}

public struct OnboardingReadyWindowState: Codable, Equatable, Sendable {
    public let readyWindowId: String
    public let readinessOutcome: DiagnosticReadinessOutcome
    public let restartHint: RestartBannerState
    public let nextActions: [OnboardingReadyNextAction]
    public let isPresented: Bool

    public init(
        readyWindowId: String = "readyWindow",
        readinessOutcome: DiagnosticReadinessOutcome,
        restartHint: RestartBannerState = RestartBannerState(),
        nextActions: [OnboardingReadyNextAction],
        isPresented: Bool = true
    ) {
        self.readyWindowId = readyWindowId
        self.readinessOutcome = readinessOutcome
        self.restartHint = restartHint
        self.nextActions = nextActions
        self.isPresented = isPresented
    }
}

public struct OnboardingReadyModel: Sendable {
    public init() {}

    public func state(
        readiness: ReadinessScanResult,
        restartHint: RestartBannerState
    ) -> OnboardingReadyWindowState {
        OnboardingReadyWindowState(
            readinessOutcome: readiness.outcome,
            restartHint: restartHint,
            nextActions: nextActions(for: readiness.outcome, restartHint: restartHint),
            isPresented: true
        )
    }

    private func nextActions(
        for outcome: DiagnosticReadinessOutcome,
        restartHint: RestartBannerState
    ) -> [OnboardingReadyNextAction] {
        switch outcome {
        case .ready:
            return restartHint.requiresRestart ? [.restartApp, .openSettings] : [.startUsing, .openSettings]
        case .partial:
            return restartHint.requiresRestart ? [.openSettings, .restartApp, .startDemo] : [.openSettings, .startDemo]
        case .demoOnly:
            return [.startDemo, .openSettings]
        case .blocked:
            return [.openSettings, .startDemo]
        }
    }
}
