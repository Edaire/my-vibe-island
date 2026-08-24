import Foundation

public struct FirstInstallState: Codable, Equatable, Sendable {
    public let hasCompletedOnboarding: Bool
    public let onboardingVersion: Int
    public let isFirstInstall: Bool
    public let forceReplayOnboarding: Bool
    public let showFirstInstallRestartBanner: Bool

    public init(
        hasCompletedOnboarding: Bool = false,
        onboardingVersion: Int = 0,
        isFirstInstall: Bool = false,
        forceReplayOnboarding: Bool = false,
        showFirstInstallRestartBanner: Bool = false
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingVersion = max(0, onboardingVersion)
        self.isFirstInstall = isFirstInstall
        self.forceReplayOnboarding = forceReplayOnboarding
        self.showFirstInstallRestartBanner = showFirstInstallRestartBanner
    }

    public func shouldPresentOnboarding(currentVersion: Int) -> Bool {
        forceReplayOnboarding
            || !hasCompletedOnboarding
            || onboardingVersion < max(0, currentVersion)
    }

    public func completed(version: Int) -> FirstInstallState {
        FirstInstallState(
            hasCompletedOnboarding: true,
            onboardingVersion: version,
            isFirstInstall: false,
            forceReplayOnboarding: false,
            showFirstInstallRestartBanner: false
        )
    }
}

public enum RestartBannerSource: String, Codable, Equatable, Sendable {
    case firstInstall
    case managedHooks
    case terminalConfiguration
    case repair
}

public struct RestartBanner: Codable, Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let affectedSources: [String]
    public let requiresRestart: Bool
    public let shownAt: String?
    public let dismissedAt: String?

    public init(
        title: String,
        subtitle: String,
        affectedSources: [String],
        requiresRestart: Bool,
        shownAt: String? = nil,
        dismissedAt: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.affectedSources = affectedSources
        self.requiresRestart = requiresRestart
        self.shownAt = shownAt
        self.dismissedAt = dismissedAt
    }
}

public struct RestartBannerState: Codable, Equatable, Sendable {
    public let visible: Bool
    public let source: RestartBannerSource?
    public let requiresRestart: Bool
    public let shownAt: String?
    public let dismissedAt: String?
    public let firstInstallOnly: Bool
    public let affectedIntegrations: [String]

    public init(
        visible: Bool = false,
        source: RestartBannerSource? = nil,
        requiresRestart: Bool = false,
        shownAt: String? = nil,
        dismissedAt: String? = nil,
        firstInstallOnly: Bool = false,
        affectedIntegrations: [String] = []
    ) {
        self.visible = visible
        self.source = source
        self.requiresRestart = requiresRestart
        self.shownAt = shownAt
        self.dismissedAt = dismissedAt
        self.firstInstallOnly = firstInstallOnly
        self.affectedIntegrations = affectedIntegrations
    }
}

public struct RestartBannerModel: Sendable {
    public init() {}

    public func state(
        firstInstallState: FirstInstallState,
        affectedIntegrations: [String],
        shownAt: String?
    ) -> RestartBannerState {
        guard firstInstallState.showFirstInstallRestartBanner,
              !affectedIntegrations.isEmpty else {
            return RestartBannerState()
        }

        return RestartBannerState(
            visible: true,
            source: .firstInstall,
            requiresRestart: true,
            shownAt: shownAt,
            firstInstallOnly: true,
            affectedIntegrations: affectedIntegrations
        )
    }

    public func dismiss(
        _ state: RestartBannerState,
        dismissedAt: String
    ) -> RestartBannerState {
        RestartBannerState(
            visible: false,
            source: state.source,
            requiresRestart: state.requiresRestart,
            shownAt: state.shownAt,
            dismissedAt: dismissedAt,
            firstInstallOnly: state.firstInstallOnly,
            affectedIntegrations: state.affectedIntegrations
        )
    }
}
