import Foundation

public struct OnboardingCoordinatorPlan: Codable, Equatable, Sendable {
    public let shouldPresentOnboarding: Bool
    public let coordinatedState: OnboardingState
    public let restartBanner: RestartBannerState
    public let readyWindow: OnboardingReadyWindowState?
    public let demoPlan: OnboardingDemoPlan

    public init(
        shouldPresentOnboarding: Bool,
        coordinatedState: OnboardingState,
        restartBanner: RestartBannerState,
        readyWindow: OnboardingReadyWindowState?,
        demoPlan: OnboardingDemoPlan
    ) {
        self.shouldPresentOnboarding = shouldPresentOnboarding
        self.coordinatedState = coordinatedState
        self.restartBanner = restartBanner
        self.readyWindow = readyWindow
        self.demoPlan = demoPlan
    }
}

public struct OnboardingCoordinator: Sendable {
    public let currentVersion: Int

    private let flowModel: OnboardingFlowModel
    private let readyModel: OnboardingReadyModel
    private let restartBannerModel: RestartBannerModel
    private let demoSessionFactory: OnboardingDemoSessionFactory

    public init(
        currentVersion: Int,
        flowModel: OnboardingFlowModel = OnboardingFlowModel(),
        readyModel: OnboardingReadyModel = OnboardingReadyModel(),
        restartBannerModel: RestartBannerModel = RestartBannerModel(),
        demoSessionFactory: OnboardingDemoSessionFactory = OnboardingDemoSessionFactory()
    ) {
        self.currentVersion = max(currentVersion, 0)
        self.flowModel = flowModel
        self.readyModel = readyModel
        self.restartBannerModel = restartBannerModel
        self.demoSessionFactory = demoSessionFactory
    }

    public func plan(
        firstInstallState: FirstInstallState,
        onboardingState: OnboardingState,
        readiness: ReadinessScanResult,
        affectedIntegrations: [String],
        demoCwd: String,
        observedAt: String?
    ) -> OnboardingCoordinatorPlan {
        let shouldPresent = firstInstallState.shouldPresentOnboarding(currentVersion: currentVersion)
        let coordinatedState = flowModel.apply(readiness: readiness, to: onboardingState)
        let restartBanner = restartBannerModel.state(
            firstInstallState: firstInstallState,
            affectedIntegrations: affectedIntegrations,
            shownAt: observedAt
        )
        let readyWindow = shouldPresent
            ? readyModel.state(readiness: readiness, restartHint: restartBanner)
            : nil

        return OnboardingCoordinatorPlan(
            shouldPresentOnboarding: shouldPresent,
            coordinatedState: coordinatedState,
            restartBanner: restartBanner,
            readyWindow: readyWindow,
            demoPlan: demoSessionFactory.makePlan(demoCwd: demoCwd)
        )
    }
}
