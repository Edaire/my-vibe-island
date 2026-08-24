import Foundation

public struct OnboardingDemoSession: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isSynthetic: Bool
    public let shouldPersistToHistory: Bool

    public init(
        id: String,
        title: String,
        isSynthetic: Bool = true,
        shouldPersistToHistory: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isSynthetic = isSynthetic
        self.shouldPersistToHistory = shouldPersistToHistory
    }
}

public struct OnboardingDemoPlan: Codable, Equatable, Sendable {
    public let reservedIdPrefix: String
    public let demoCwd: String
    public let demoSource: String
    public let sessions: [OnboardingDemoSession]
    public let previewCompletionSessionId: String

    public init(
        reservedIdPrefix: String = "demo-onboarding-",
        demoCwd: String,
        demoSource: String = "onboarding",
        sessions: [OnboardingDemoSession],
        previewCompletionSessionId: String
    ) {
        self.reservedIdPrefix = reservedIdPrefix
        self.demoCwd = demoCwd
        self.demoSource = demoSource
        self.sessions = sessions
        self.previewCompletionSessionId = previewCompletionSessionId
    }
}

public struct OnboardingDemoSessionFactory: Sendable {
    public init() {}

    public func makePlan(demoCwd: String) -> OnboardingDemoPlan {
        OnboardingDemoPlan(
            demoCwd: demoCwd,
            sessions: [
                OnboardingDemoSession(id: "demo-onboarding-permission", title: "Permission"),
                OnboardingDemoSession(id: "demo-onboarding-question", title: "Question"),
                OnboardingDemoSession(id: "demo-onboarding-completion", title: "Completion"),
                OnboardingDemoSession(id: "demo-onboarding-notification", title: "Notification"),
            ],
            previewCompletionSessionId: "demo-onboarding-completion"
        )
    }
}

public struct OnboardingDemoRunnerState: Codable, Equatable, Sendable {
    public let socketPath: String?
    public let defaultCwd: String
    public let persistentFd: Int?
    public let defaultEnv: [String: String]
    public let demoSessionIds: [String]
    public let activeSessionIds: [String]
    public let previewCompletionSessionId: String?
    public let startedAt: String?

    public var isRunning: Bool {
        !activeSessionIds.isEmpty
    }

    public init(
        socketPath: String? = nil,
        defaultCwd: String,
        persistentFd: Int? = nil,
        defaultEnv: [String: String] = [:],
        demoSessionIds: [String] = [],
        activeSessionIds: [String] = [],
        previewCompletionSessionId: String? = nil,
        startedAt: String? = nil
    ) {
        self.socketPath = socketPath
        self.defaultCwd = defaultCwd
        self.persistentFd = persistentFd.map { max(0, $0) }
        self.defaultEnv = defaultEnv
        self.demoSessionIds = demoSessionIds
        self.activeSessionIds = activeSessionIds
        self.previewCompletionSessionId = previewCompletionSessionId
        self.startedAt = startedAt
    }
}

public enum OnboardingDemoRunnerDecision: String, Codable, Equatable, Sendable {
    case started
    case finished
}

public struct OnboardingDemoRunnerResult: Codable, Equatable, Sendable {
    public let decision: OnboardingDemoRunnerDecision
    public let nextState: OnboardingDemoRunnerState

    public init(
        decision: OnboardingDemoRunnerDecision,
        nextState: OnboardingDemoRunnerState
    ) {
        self.decision = decision
        self.nextState = nextState
    }
}

public struct OnboardingDemoRunnerModel: Sendable {
    public init() {}

    public func start(
        plan: OnboardingDemoPlan,
        socketPath: String?,
        persistentFd: Int?,
        defaultEnv: [String: String],
        startedAt: String?
    ) -> OnboardingDemoRunnerResult {
        OnboardingDemoRunnerResult(
            decision: .started,
            nextState: OnboardingDemoRunnerState(
                socketPath: socketPath,
                defaultCwd: plan.demoCwd,
                persistentFd: persistentFd,
                defaultEnv: defaultEnv,
                demoSessionIds: plan.sessions.map(\.id),
                activeSessionIds: plan.sessions.first.map { [$0.id] } ?? [],
                previewCompletionSessionId: plan.previewCompletionSessionId,
                startedAt: startedAt
            )
        )
    }

    public func finish(from state: OnboardingDemoRunnerState) -> OnboardingDemoRunnerResult {
        OnboardingDemoRunnerResult(
            decision: .finished,
            nextState: OnboardingDemoRunnerState(
                socketPath: state.socketPath,
                defaultCwd: state.defaultCwd,
                persistentFd: state.persistentFd,
                defaultEnv: state.defaultEnv,
                demoSessionIds: state.demoSessionIds,
                activeSessionIds: [],
                previewCompletionSessionId: state.previewCompletionSessionId,
                startedAt: state.startedAt
            )
        )
    }
}
