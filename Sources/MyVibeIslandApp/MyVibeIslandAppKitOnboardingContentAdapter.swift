import MyVibeIslandCore

public struct MyVibeIslandAppKitOnboardingStepDescriptor: Equatable {
    public let step: OnboardingStep
    public let title: String
    public let isCurrent: Bool
    public let isCompleted: Bool
    public let isSkipped: Bool

    public init(
        step: OnboardingStep,
        title: String,
        isCurrent: Bool,
        isCompleted: Bool,
        isSkipped: Bool
    ) {
        self.step = step
        self.title = title
        self.isCurrent = isCurrent
        self.isCompleted = isCompleted
        self.isSkipped = isSkipped
    }
}

public struct MyVibeIslandAppKitOnboardingProgressDescriptor: Equatable {
    public let completedCount: Int
    public let totalCount: Int

    public init(completedCount: Int, totalCount: Int) {
        self.completedCount = max(completedCount, 0)
        self.totalCount = max(totalCount, 0)
    }
}

public struct MyVibeIslandAppKitOnboardingContentDescriptor: Equatable {
    public let currentStep: OnboardingStep
    public let currentStepTitle: String
    public let steps: [MyVibeIslandAppKitOnboardingStepDescriptor]
    public let progress: MyVibeIslandAppKitOnboardingProgressDescriptor
    public let canContinue: Bool
    public let blockingIssue: String?
    public let readinessOutcome: DiagnosticReadinessOutcome?

    public init(
        currentStep: OnboardingStep,
        currentStepTitle: String,
        steps: [MyVibeIslandAppKitOnboardingStepDescriptor],
        progress: MyVibeIslandAppKitOnboardingProgressDescriptor,
        canContinue: Bool,
        blockingIssue: String?,
        readinessOutcome: DiagnosticReadinessOutcome?
    ) {
        self.currentStep = currentStep
        self.currentStepTitle = currentStepTitle
        self.steps = steps
        self.progress = progress
        self.canContinue = canContinue
        self.blockingIssue = blockingIssue
        self.readinessOutcome = readinessOutcome
    }
}

public struct MyVibeIslandAppKitOnboardingReadyWindowDescriptor: Equatable {
    public let readyWindowId: String
    public let readinessOutcome: DiagnosticReadinessOutcome
    public let isPresented: Bool
    public let restartVisible: Bool
    public let restartSource: RestartBannerSource?
    public let requiresRestart: Bool
    public let affectedIntegrationCount: Int
    public let nextActions: [OnboardingReadyNextAction]
    public let canStartDemo: Bool
    public let canStartUsing: Bool

    public init(
        readyWindowId: String,
        readinessOutcome: DiagnosticReadinessOutcome,
        isPresented: Bool,
        restartVisible: Bool,
        restartSource: RestartBannerSource?,
        requiresRestart: Bool,
        affectedIntegrationCount: Int,
        nextActions: [OnboardingReadyNextAction],
        canStartDemo: Bool,
        canStartUsing: Bool
    ) {
        self.readyWindowId = readyWindowId
        self.readinessOutcome = readinessOutcome
        self.isPresented = isPresented
        self.restartVisible = restartVisible
        self.restartSource = restartSource
        self.requiresRestart = requiresRestart
        self.affectedIntegrationCount = max(affectedIntegrationCount, 0)
        self.nextActions = nextActions
        self.canStartDemo = canStartDemo
        self.canStartUsing = canStartUsing
    }
}

public struct MyVibeIslandAppKitOnboardingDemoRunnerDescriptor: Equatable {
    public let isRunning: Bool
    public let defaultCwd: String
    public let demoSessionCount: Int
    public let activeSessionCount: Int
    public let previewCompletionSessionId: String?
    public let hasSocketPath: Bool
    public let hasPersistentFd: Bool
    public let environmentKeyCount: Int
    public let startedAt: String?

    public init(
        isRunning: Bool,
        defaultCwd: String,
        demoSessionCount: Int,
        activeSessionCount: Int,
        previewCompletionSessionId: String?,
        hasSocketPath: Bool,
        hasPersistentFd: Bool,
        environmentKeyCount: Int,
        startedAt: String?
    ) {
        self.isRunning = isRunning
        self.defaultCwd = defaultCwd
        self.demoSessionCount = max(demoSessionCount, 0)
        self.activeSessionCount = max(activeSessionCount, 0)
        self.previewCompletionSessionId = previewCompletionSessionId
        self.hasSocketPath = hasSocketPath
        self.hasPersistentFd = hasPersistentFd
        self.environmentKeyCount = max(environmentKeyCount, 0)
        self.startedAt = startedAt
    }
}

public struct MyVibeIslandAppKitOnboardingContentAdapter {
    public init() {}

    public func makeDescriptor(from state: OnboardingState) -> MyVibeIslandAppKitOnboardingContentDescriptor {
        MyVibeIslandAppKitOnboardingContentDescriptor(
            currentStep: state.currentStep,
            currentStepTitle: title(for: state.currentStep),
            steps: OnboardingStep.allCases.map { step in
                MyVibeIslandAppKitOnboardingStepDescriptor(
                    step: step,
                    title: title(for: step),
                    isCurrent: step == state.currentStep,
                    isCompleted: state.completedSteps.contains(step),
                    isSkipped: state.skippedSteps.contains(step)
                )
            },
            progress: MyVibeIslandAppKitOnboardingProgressDescriptor(
                completedCount: state.completedSteps.count,
                totalCount: OnboardingStep.allCases.count
            ),
            canContinue: state.canContinue,
            blockingIssue: state.blockingIssue,
            readinessOutcome: state.readinessOutcome
        )
    }

    public func makeReadyWindowDescriptor(
        from state: OnboardingReadyWindowState
    ) -> MyVibeIslandAppKitOnboardingReadyWindowDescriptor {
        MyVibeIslandAppKitOnboardingReadyWindowDescriptor(
            readyWindowId: state.readyWindowId,
            readinessOutcome: state.readinessOutcome,
            isPresented: state.isPresented,
            restartVisible: state.restartHint.visible,
            restartSource: state.restartHint.source,
            requiresRestart: state.restartHint.requiresRestart,
            affectedIntegrationCount: state.restartHint.affectedIntegrations.count,
            nextActions: state.nextActions,
            canStartDemo: state.nextActions.contains(.startDemo),
            canStartUsing: state.nextActions.contains(.startUsing)
        )
    }

    public func makeDemoRunnerDescriptor(
        from state: OnboardingDemoRunnerState
    ) -> MyVibeIslandAppKitOnboardingDemoRunnerDescriptor {
        MyVibeIslandAppKitOnboardingDemoRunnerDescriptor(
            isRunning: state.isRunning,
            defaultCwd: state.defaultCwd,
            demoSessionCount: state.demoSessionIds.count,
            activeSessionCount: state.activeSessionIds.count,
            previewCompletionSessionId: state.previewCompletionSessionId,
            hasSocketPath: state.socketPath != nil,
            hasPersistentFd: state.persistentFd != nil,
            environmentKeyCount: state.defaultEnv.count,
            startedAt: state.startedAt
        )
    }

    private func title(for step: OnboardingStep) -> String {
        switch step {
        case .welcome:
            return "Welcome"
        case .localPrivacy:
            return "Local Privacy"
        case .environmentScan:
            return "Environment Scan"
        case .integrationSelection:
            return "Integration Selection"
        case .installRepair:
            return "Install & Repair"
        case .permissions:
            return "Permissions"
        case .demo:
            return "Demo"
        case .verification:
            return "Verification"
        case .ready:
            return "Ready"
        }
    }
}
