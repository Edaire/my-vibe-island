import Foundation

public struct OnboardingVisualState: Codable, Equatable, Sendable {
    public let glowIntensity: Double
    public let glowRotation: Double
    public let cornerBounce: Double
    public let isGlowActive: Bool
    public let isHidingNotch: Bool
    public let onboardingRainbow: Bool

    public static let idle = OnboardingVisualState(
        glowIntensity: 0.0,
        glowRotation: 0.0,
        cornerBounce: 0.0,
        isGlowActive: false,
        isHidingNotch: false,
        onboardingRainbow: false
    )

    public init(
        glowIntensity: Double = 0.0,
        glowRotation: Double = 0.0,
        cornerBounce: Double = 0.0,
        isGlowActive: Bool = false,
        isHidingNotch: Bool = false,
        onboardingRainbow: Bool = false
    ) {
        self.glowIntensity = Self.clampUnit(glowIntensity)
        self.glowRotation = Self.normalizedRotation(glowRotation)
        self.cornerBounce = Self.clampUnit(cornerBounce)
        self.isGlowActive = isGlowActive
        self.isHidingNotch = isHidingNotch
        self.onboardingRainbow = onboardingRainbow
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private static func normalizedRotation(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360.0)
        return remainder < 0 ? remainder + 360.0 : remainder
    }
}

public struct OnboardingVisualStateModel: Sendable {
    public init() {}

    public func state(
        for step: OnboardingStep,
        previous: OnboardingVisualState
    ) -> OnboardingVisualState {
        guard step != .ready else {
            return .idle
        }

        return OnboardingVisualState(
            glowIntensity: step == .demo ? 1.0 : max(previous.glowIntensity, 0.65),
            glowRotation: previous.glowRotation + rotationDelta(for: step),
            cornerBounce: step == .demo ? 0.45 : 0.2,
            isGlowActive: true,
            isHidingNotch: step == .demo,
            onboardingRainbow: true
        )
    }

    private func rotationDelta(for step: OnboardingStep) -> Double {
        switch step {
        case .welcome, .localPrivacy:
            return 24.0
        case .environmentScan, .integrationSelection, .installRepair, .permissions:
            return 36.0
        case .demo:
            return 54.0
        case .verification:
            return 18.0
        case .ready:
            return 0.0
        }
    }
}
