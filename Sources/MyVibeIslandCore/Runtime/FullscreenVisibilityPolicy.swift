public struct FullscreenVisibilityInput: Codable, Equatable, Sendable {
    public let hideInFullscreen: Bool
    public let activeAppIsFullscreen: Bool
    public let blockingActionVisible: Bool
    public let onboardingFullscreenActive: Bool
    public let fullscreenCheckGeneration: Int

    public init(
        hideInFullscreen: Bool,
        activeAppIsFullscreen: Bool,
        blockingActionVisible: Bool = false,
        onboardingFullscreenActive: Bool = false,
        fullscreenCheckGeneration: Int = 0
    ) {
        self.hideInFullscreen = hideInFullscreen
        self.activeAppIsFullscreen = activeAppIsFullscreen
        self.blockingActionVisible = blockingActionVisible
        self.onboardingFullscreenActive = onboardingFullscreenActive
        self.fullscreenCheckGeneration = fullscreenCheckGeneration
    }
}

public enum FullscreenVisibilityReason: String, Codable, Equatable, Sendable {
    case visible
    case fullscreenHidden
    case blockingActionVisible
    case onboardingFullscreen
}

public struct FullscreenVisibilityDecision: Codable, Equatable, Sendable {
    public let isVisible: Bool
    public let reason: FullscreenVisibilityReason
    public let fullscreenCheckGeneration: Int

    public init(
        isVisible: Bool,
        reason: FullscreenVisibilityReason,
        fullscreenCheckGeneration: Int
    ) {
        self.isVisible = isVisible
        self.reason = reason
        self.fullscreenCheckGeneration = fullscreenCheckGeneration
    }
}

public struct FullscreenVisibilityPolicy: Sendable {
    public init() {}

    public func decide(_ input: FullscreenVisibilityInput) -> FullscreenVisibilityDecision {
        if input.onboardingFullscreenActive {
            return decision(false, .onboardingFullscreen, input)
        }

        if input.blockingActionVisible {
            return decision(true, .blockingActionVisible, input)
        }

        if input.hideInFullscreen && input.activeAppIsFullscreen {
            return decision(false, .fullscreenHidden, input)
        }

        return decision(true, .visible, input)
    }

    private func decision(
        _ isVisible: Bool,
        _ reason: FullscreenVisibilityReason,
        _ input: FullscreenVisibilityInput
    ) -> FullscreenVisibilityDecision {
        FullscreenVisibilityDecision(
            isVisible: isVisible,
            reason: reason,
            fullscreenCheckGeneration: input.fullscreenCheckGeneration
        )
    }
}
