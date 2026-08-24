import Foundation

public enum OnboardingStep: String, Codable, Equatable, CaseIterable, Sendable {
    case welcome
    case localPrivacy
    case environmentScan
    case integrationSelection
    case installRepair
    case permissions
    case demo
    case verification
    case ready

    public var next: OnboardingStep? {
        guard let index = Self.allCases.firstIndex(of: self) else {
            return nil
        }
        let nextIndex = Self.allCases.index(after: index)
        guard nextIndex < Self.allCases.endIndex else {
            return nil
        }
        return Self.allCases[nextIndex]
    }
}

public struct OnboardingState: Codable, Equatable, Sendable {
    public let currentStep: OnboardingStep
    public let completedSteps: [OnboardingStep]
    public let skippedSteps: [OnboardingStep]
    public let canContinue: Bool
    public let blockingIssue: String?
    public let readinessOutcome: DiagnosticReadinessOutcome?

    public init(
        currentStep: OnboardingStep = .welcome,
        completedSteps: [OnboardingStep] = [],
        skippedSteps: [OnboardingStep] = [],
        canContinue: Bool = true,
        blockingIssue: String? = nil,
        readinessOutcome: DiagnosticReadinessOutcome? = nil
    ) {
        self.currentStep = currentStep
        self.completedSteps = Self.normalized(completedSteps)
        self.skippedSteps = Self.normalized(skippedSteps)
        self.canContinue = canContinue
        self.blockingIssue = blockingIssue
        self.readinessOutcome = readinessOutcome
    }

    private static func normalized(_ steps: [OnboardingStep]) -> [OnboardingStep] {
        var seen: Set<OnboardingStep> = []
        var result: [OnboardingStep] = []
        for step in steps where !seen.contains(step) {
            seen.insert(step)
            result.append(step)
        }
        return result
    }
}

public enum OnboardingFlowDecision: String, Codable, Equatable, Sendable {
    case advanced
    case blocked
    case alreadyReady
}

public struct OnboardingFlowResult: Codable, Equatable, Sendable {
    public let decision: OnboardingFlowDecision
    public let nextState: OnboardingState

    public init(
        decision: OnboardingFlowDecision,
        nextState: OnboardingState
    ) {
        self.decision = decision
        self.nextState = nextState
    }
}

public struct OnboardingFlowModel: Sendable {
    public init() {}

    public func advance(from state: OnboardingState) -> OnboardingFlowResult {
        guard state.canContinue else {
            return OnboardingFlowResult(decision: .blocked, nextState: state)
        }

        guard let nextStep = state.currentStep.next else {
            return OnboardingFlowResult(decision: .alreadyReady, nextState: state)
        }

        return OnboardingFlowResult(
            decision: .advanced,
            nextState: OnboardingState(
                currentStep: nextStep,
                completedSteps: state.completedSteps + [state.currentStep],
                skippedSteps: state.skippedSteps,
                canContinue: state.canContinue,
                blockingIssue: state.blockingIssue,
                readinessOutcome: state.readinessOutcome
            )
        )
    }

    public func apply(
        readiness: ReadinessScanResult,
        to state: OnboardingState
    ) -> OnboardingState {
        let blockingIssue = readiness.blockingIssues.first
        return OnboardingState(
            currentStep: state.currentStep,
            completedSteps: state.completedSteps,
            skippedSteps: state.skippedSteps,
            canContinue: blockingIssue == nil,
            blockingIssue: blockingIssue,
            readinessOutcome: readiness.outcome
        )
    }
}
