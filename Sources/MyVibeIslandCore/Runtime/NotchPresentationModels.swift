public enum PillVisualState: String, Codable, Equatable, Sendable {
    case hidden
    case idle
    case active
    case waiting
    case completed
    case failed
    case mixed
}

public enum PillRightSlotContent: Codable, Equatable, Sendable {
    case none
    case usageRing(UsageRingBadge)
    case unreadCompletion(count: Int)
    case waitingAction(count: Int)
    case activeCount(Int)
}

public enum DisplayIntentReason: String, Codable, Equatable, Sendable {
    case none
    case userHover
    case keyboardShortcut
    case notificationPeek
    case taskComplete
    case blockingAction
    case onboarding
    case fullscreenHide
    case autoCollapse
    case outsideClick
}

public struct PillSnapshot: Codable, Equatable, Sendable {
    public let primaryAgent: String?
    public let activeCount: Int
    public let waitingCount: Int
    public let completedUnreadCount: Int
    public let usageInfoBar: UsageInfoBar?
    public let visualState: PillVisualState
    public let rightSlotContent: PillRightSlotContent

    public init(
        primaryAgent: String? = nil,
        activeCount: Int = 0,
        waitingCount: Int = 0,
        completedUnreadCount: Int = 0,
        usageInfoBar: UsageInfoBar? = nil,
        visualState: PillVisualState = .hidden,
        rightSlotContent: PillRightSlotContent = .none
    ) {
        self.primaryAgent = primaryAgent
        self.activeCount = activeCount
        self.waitingCount = waitingCount
        self.completedUnreadCount = completedUnreadCount
        self.usageInfoBar = usageInfoBar
        self.visualState = visualState
        self.rightSlotContent = rightSlotContent
    }
}

public struct CompletionUnreadDot: Codable, Equatable, Sendable {
    public let count: Int

    public var isVisible: Bool {
        count > 0
    }

    public var accessibilityLabel: String {
        count == 1 ? "1 unread completion" : "\(count) unread completions"
    }

    public init(count: Int = 0) {
        self.count = max(0, count)
    }

    public init(snapshot: PillSnapshot) {
        self.init(count: snapshot.completedUnreadCount)
    }

    public init(
        snapshot: PillSnapshot,
        autoExpandOnTaskComplete: Bool,
        completionOverviewSeen: Bool,
        quietSceneCompletionPending: Bool = false
    ) {
        self.init(count: (autoExpandOnTaskComplete && quietSceneCompletionPending) || completionOverviewSeen
            ? 0
            : snapshot.completedUnreadCount)
    }
}

public enum StateIndicatorKind: String, Codable, Equatable, Sendable {
    case hidden
    case idle
    case active
    case waiting
    case completed
    case failed
    case mixed
}

public struct StateIndicator: Codable, Equatable, Sendable {
    public let kind: StateIndicatorKind
    public let count: Int

    public var isVisible: Bool {
        kind != .hidden
    }

    public var accessibilityLabel: String {
        switch kind {
        case .hidden:
            return "No session state"
        case .idle:
            return "Idle"
        case .active:
            return count == 1 ? "1 active session" : "\(count) active sessions"
        case .waiting:
            return count == 1 ? "1 waiting action" : "\(count) waiting actions"
        case .completed:
            return count == 1 ? "1 completed session" : "\(count) completed sessions"
        case .failed:
            return count == 1 ? "1 failed session" : "\(count) failed sessions"
        case .mixed:
            return "Mixed session state"
        }
    }

    public init(kind: StateIndicatorKind, count: Int = 0) {
        self.kind = kind
        self.count = max(0, count)
    }

    public init(snapshot: PillSnapshot) {
        self.init(
            kind: StateIndicatorKind(snapshot.visualState),
            count: Self.count(for: snapshot)
        )
    }

    private static func count(for snapshot: PillSnapshot) -> Int {
        switch snapshot.visualState {
        case .active:
            return snapshot.activeCount
        case .waiting:
            return snapshot.waitingCount
        case .completed:
            return snapshot.completedUnreadCount
        case .hidden, .idle, .failed, .mixed:
            return 0
        }
    }
}

private extension StateIndicatorKind {
    init(_ visualState: PillVisualState) {
        switch visualState {
        case .hidden:
            self = .hidden
        case .idle:
            self = .idle
        case .active:
            self = .active
        case .waiting:
            self = .waiting
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .mixed:
            self = .mixed
        }
    }
}

public struct NotchPresentationState: Codable, Equatable, Sendable {
    public let displayState: PanelDisplayState
    public let rootContentStatus: NotchRootContentStatus
    public let focusedSessionId: String?
    public let pillSnapshot: PillSnapshot
    public let interactionState: PanelInteractionState
    public let sessionPreviews: [SessionCardPreview]
    public let notificationPreviews: [SessionCardPreview]
    public let displayReason: DisplayIntentReason
    public let isPreviewingCompletionCard: Bool
    public let completionPreviewSessionID: String?
    public let completionPreview: SessionCardPreview?
    public let completionPreviewSession: AgentSession?

    public init(
        displayState: PanelDisplayState = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        focusedSessionId: String? = nil,
        pillSnapshot: PillSnapshot = PillSnapshot(),
        interactionState: PanelInteractionState = PanelInteractionState(),
        sessionPreviews: [SessionCardPreview] = [],
        notificationPreviews: [SessionCardPreview] = [],
        displayReason: DisplayIntentReason = .none,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil
    ) {
        self.displayState = displayState
        self.rootContentStatus = rootContentStatus
            ?? NotchRootContentStatus(displayStatus: NotchDisplayStatus(displayState: displayState))
        self.focusedSessionId = focusedSessionId
        self.pillSnapshot = pillSnapshot
        self.interactionState = interactionState
        self.sessionPreviews = sessionPreviews
        self.notificationPreviews = notificationPreviews
        self.displayReason = displayReason
        self.isPreviewingCompletionCard = isPreviewingCompletionCard
        self.completionPreviewSessionID = completionPreviewSessionID
        self.completionPreview = completionPreview
        self.completionPreviewSession = completionPreviewSession
    }

    private enum CodingKeys: String, CodingKey {
        case displayState
        case rootContentStatus
        case focusedSessionId
        case pillSnapshot
        case interactionState
        case sessionPreviews
        case notificationPreviews
        case displayReason
        case isPreviewingCompletionCard
        case completionPreviewSessionID
        case completionPreview
        case completionPreviewSession
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayState = try container.decode(PanelDisplayState.self, forKey: .displayState)
        self.init(
            displayState: displayState,
            rootContentStatus: try container.decodeIfPresent(
                NotchRootContentStatus.self,
                forKey: .rootContentStatus
            ),
            focusedSessionId: try container.decodeIfPresent(String.self, forKey: .focusedSessionId),
            pillSnapshot: try container.decode(PillSnapshot.self, forKey: .pillSnapshot),
            interactionState: try container.decode(PanelInteractionState.self, forKey: .interactionState),
            sessionPreviews: try container.decode([SessionCardPreview].self, forKey: .sessionPreviews),
            notificationPreviews: try container.decode([SessionCardPreview].self, forKey: .notificationPreviews),
            displayReason: try container.decode(DisplayIntentReason.self, forKey: .displayReason),
            isPreviewingCompletionCard: try container.decode(Bool.self, forKey: .isPreviewingCompletionCard),
            completionPreviewSessionID: try container.decodeIfPresent(
                String.self,
                forKey: .completionPreviewSessionID
            ),
            completionPreview: try container.decodeIfPresent(SessionCardPreview.self, forKey: .completionPreview),
            completionPreviewSession: try container.decodeIfPresent(
                AgentSession.self,
                forKey: .completionPreviewSession
            )
        )
    }
}

public struct NotchPresentationBuilder: Sendable {
    public init() {}

    public func pillSnapshot(
        previews: [SessionCardPreview],
        usageDisplayState: UsageDisplayState? = nil
    ) -> PillSnapshot {
        let activeCount = previews.filter { $0.statusBadge == SessionStatus.active.rawValue }.count
        let waitingCount = previews.filter { $0.statusBadge == SessionStatus.waiting.rawValue }.count
        let completedUnreadCount = previews.filter(\.unreadCompletionMarker).count
        let usageInfoBar = usageDisplayState.map(UsageInfoBar.make(displayState:))

        return PillSnapshot(
            primaryAgent: primaryAgent(in: previews),
            activeCount: activeCount,
            waitingCount: waitingCount,
            completedUnreadCount: completedUnreadCount,
            usageInfoBar: usageInfoBar,
            visualState: visualState(for: previews),
            rightSlotContent: rightSlotContent(
                activeCount: activeCount,
                waitingCount: waitingCount,
                completedUnreadCount: completedUnreadCount,
                usageDisplayState: usageDisplayState
            )
        )
    }

    public func presentationState(
        displayState: PanelDisplayState,
        rootContentStatus: NotchRootContentStatus? = nil,
        previews: [SessionCardPreview],
        focusedSessionId: String?,
        interactionState: PanelInteractionState,
        usageDisplayState: UsageDisplayState? = nil,
        notificationPreviews: [SessionCardPreview] = [],
        displayReason: DisplayIntentReason = .none,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil
    ) -> NotchPresentationState {
        NotchPresentationState(
            displayState: displayState,
            rootContentStatus: rootContentStatus ?? interactionState.rootContentStatus,
            focusedSessionId: validFocusedSessionId(focusedSessionId, in: previews),
            pillSnapshot: pillSnapshot(previews: previews, usageDisplayState: usageDisplayState),
            interactionState: interactionState,
            sessionPreviews: previews,
            notificationPreviews: notificationPreviews,
            displayReason: displayReason,
            isPreviewingCompletionCard: isPreviewingCompletionCard,
            completionPreviewSessionID: completionPreviewSessionID,
            completionPreview: completionPreview,
            completionPreviewSession: completionPreviewSession
        )
    }

    private func primaryAgent(in previews: [SessionCardPreview]) -> String? {
        previews.first?.sourceBadge
    }

    private func visualState(for previews: [SessionCardPreview]) -> PillVisualState {
        guard !previews.isEmpty else {
            return .hidden
        }

        let statuses = Set(previews.map(\.statusBadge))
        if statuses.contains(SessionStatus.waiting.rawValue) {
            return .waiting
        }
        if statuses.contains(SessionStatus.failed.rawValue) {
            return .failed
        }
        if statuses.contains(SessionStatus.active.rawValue) {
            return .active
        }
        if previews.contains(where: \.unreadCompletionMarker)
            || statuses.contains(SessionStatus.completed.rawValue) {
            return .completed
        }
        if statuses.count > 1 {
            return .mixed
        }
        return .idle
    }

    private func rightSlotContent(
        activeCount: Int,
        waitingCount: Int,
        completedUnreadCount: Int,
        usageDisplayState: UsageDisplayState?
    ) -> PillRightSlotContent {
        if waitingCount > 0 {
            return .waitingAction(count: waitingCount)
        }
        if completedUnreadCount > 0 {
            return .unreadCompletion(count: completedUnreadCount)
        }
        if let usageDisplayState, usageDisplayState.displayStyle == .ringBadge {
            return .usageRing(UsageRingBadge.make(displayState: usageDisplayState))
        }
        if activeCount > 1 {
            return .activeCount(activeCount)
        }
        return .none
    }

    private func validFocusedSessionId(
        _ focusedSessionId: String?,
        in previews: [SessionCardPreview]
    ) -> String? {
        guard let focusedSessionId,
              previews.contains(where: { $0.sessionId == focusedSessionId }) else {
            return nil
        }

        return focusedSessionId
    }
}
