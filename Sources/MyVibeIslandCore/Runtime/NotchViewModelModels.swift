public struct QuestionSelectionState: Codable, Equatable, Sendable {
    public let selections: [String: String]

    public init(selections: [String: String] = [:]) {
        self.selections = selections
    }

    public func recording(requestId: String, selection: String) -> QuestionSelectionState {
        var nextSelections = selections
        nextSelections[requestId] = selection
        return QuestionSelectionState(selections: nextSelections)
    }
}

public struct NotchLocalUIPreferences: Codable, Equatable, Sendable {
    public let showUsageInPill: Bool
    public let reduceMotion: Bool
    public let compactMode: Bool

    public init(
        showUsageInPill: Bool = false,
        reduceMotion: Bool = false,
        compactMode: Bool = true
    ) {
        self.showUsageInPill = showUsageInPill
        self.reduceMotion = reduceMotion
        self.compactMode = compactMode
    }
}

public enum NotchDisplayStatus: String, Codable, Equatable, Sendable {
    case closed
    case opening
    case expanded
    case notificationPeek
    case switcher
    case onboarding
    case hidden
    case autoHidden

    public init(displayState: PanelDisplayState) {
        switch displayState {
        case .closed:
            self = .closed
        case .opening:
            self = .opening
        case .expanded:
            self = .expanded
        case .notificationPeek:
            self = .notificationPeek
        case .switcher:
            self = .switcher
        case .onboarding:
            self = .onboarding
        case .hidden:
            self = .hidden
        case .autoHidden:
            self = .autoHidden
        }
    }
}

/// The root branch is distinct from the presentation intent. The original
/// NotchViewModel stores these as separate fields (`_notchStatus` and
/// `_displayState`), so a completion preview can use the expanded root without
/// becoming a distinct popup intent.
public enum NotchRootContentStatus: String, Codable, Equatable, Sendable {
    case none
    case compact
    case expanded

    public init(displayStatus: NotchDisplayStatus) {
        switch displayStatus {
        case .closed, .opening, .notificationPeek, .onboarding:
            self = .compact
        case .expanded, .switcher:
            self = .expanded
        case .hidden, .autoHidden:
            self = .none
        }
    }

    public var usesExpandedContent: Bool {
        self == .expanded
    }
}

public enum NotchLayoutMode: String, Codable, Equatable, Sendable {
    case compact
    case regular
    case expanded

    public init(displayState: PanelDisplayState, preferences: NotchLocalUIPreferences) {
        if preferences.compactMode {
            self = .compact
        } else if displayState == .expanded || displayState == .onboarding || displayState == .switcher {
            self = .expanded
        } else {
            self = .regular
        }
    }
}

public struct DisplayIntentFocusedSnapshot: Codable, Equatable, Sendable {
    public let focusedSessionId: String?
    public let displayStatus: NotchDisplayStatus
    public let layoutMode: NotchLayoutMode
    public let blockingKind: DisplayBlockingKind?
    public let transientRevealKind: TransientAutoRevealKind?

    public init(
        focusedSessionId: String?,
        displayStatus: NotchDisplayStatus,
        layoutMode: NotchLayoutMode,
        blockingKind: DisplayBlockingKind? = nil,
        transientRevealKind: TransientAutoRevealKind? = nil
    ) {
        self.focusedSessionId = focusedSessionId
        self.displayStatus = displayStatus
        self.layoutMode = layoutMode
        self.blockingKind = blockingKind
        self.transientRevealKind = transientRevealKind
    }

    public init(state: NotchViewModelState) {
        let presentation = state.overlayState.panelState.presentationState
        self.init(
            focusedSessionId: presentation.focusedSessionId,
            displayStatus: NotchDisplayStatus(displayState: presentation.displayState),
            layoutMode: NotchLayoutMode(
                displayState: presentation.displayState,
                preferences: state.localPreferences
            ),
            blockingKind: DisplayBlockingKind(state: presentation.interactionState),
            transientRevealKind: presentation.interactionState.transientAutoRevealKind
        )
    }
}

public struct NotchSessionSets: Codable, Equatable, Sendable {
    public let visibleSessionIds: [String]
    public let focusedSessionId: String?
    public let deferredSessionIds: [String]
    public let bypassedSessionIds: [String]
    public let unreadSessionIds: [String]

    public init(
        visibleSessionIds: [String] = [],
        focusedSessionId: String? = nil,
        deferredSessionIds: [String] = [],
        bypassedSessionIds: [String] = [],
        unreadSessionIds: [String] = []
    ) {
        self.visibleSessionIds = Self.unique(visibleSessionIds)
        self.focusedSessionId = focusedSessionId
        self.deferredSessionIds = Self.unique(deferredSessionIds)
        self.bypassedSessionIds = Self.unique(bypassedSessionIds)
        self.unreadSessionIds = Self.unique(unreadSessionIds)
    }

    public init(state: NotchViewModelState) {
        let previews = state.sessionPreviews
        self.init(
            visibleSessionIds: previews.map(\.sessionId),
            focusedSessionId: state.overlayState.panelState.presentationState.focusedSessionId
                ?? state.focusedSessionId,
            deferredSessionIds: previews.filter(\.restored).map(\.sessionId),
            bypassedSessionIds: previews.filter { !$0.jumpAvailable }.map(\.sessionId),
            unreadSessionIds: (state.notificationPreviews + previews)
                .filter(\.unreadCompletionMarker)
                .map(\.sessionId)
        )
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

public struct NotchContentDimensions: Codable, Equatable, Sendable {
    public let closedSize: DisplaySize
    public let expandedSize: DisplaySize
    public let activeContentSize: DisplaySize
    public let safeAreaAdjustment: Double

    public init(
        closedSize: DisplaySize = DisplaySize(width: 0, height: 0),
        expandedSize: DisplaySize = DisplaySize(width: 0, height: 0),
        activeContentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        safeAreaAdjustment: Double = 0
    ) {
        self.closedSize = closedSize
        self.expandedSize = expandedSize
        self.activeContentSize = activeContentSize
        self.safeAreaAdjustment = max(0, safeAreaAdjustment)
    }

    public init(
        placementPlan: DisplayPlacementPlan?,
        displayStatus: NotchDisplayStatus
    ) {
        self.init(
            placementPlan: placementPlan,
            rootContentStatus: NotchRootContentStatus(displayStatus: displayStatus)
        )
    }

    public init(
        placementPlan: DisplayPlacementPlan?,
        rootContentStatus: NotchRootContentStatus
    ) {
        guard let placementPlan else {
            self.init()
            return
        }

        let closedSize = DisplaySize(
            width: placementPlan.closedFrame.width,
            height: placementPlan.closedFrame.height
        )
        let expandedSize = DisplaySize(
            width: placementPlan.expandedFrame.width,
            height: placementPlan.expandedFrame.height
        )

        self.init(
            closedSize: closedSize,
            expandedSize: expandedSize,
            activeContentSize: rootContentStatus.usesExpandedContent ? expandedSize : closedSize,
            safeAreaAdjustment: placementPlan.safeAreaAdjustment
        )
    }
}

public struct IslandSurfaceSnapshot: Codable, Equatable, Sendable {
    public let sessions: [AgentSession]
    public let originalCompactRuntimeState: OriginalCompactRuntimeState
    public let displayStatus: NotchDisplayStatus
    public let layoutMode: NotchLayoutMode
    public let focusedSessionId: String?
    public let presentationState: NotchPresentationState
    public let sessionSets: NotchSessionSets
    public let contentDimensions: NotchContentDimensions
    public let pillSnapshot: PillSnapshot
    public let completionUnreadDot: CompletionUnreadDot
    public let stateIndicator: StateIndicator
    public let usagePresentation: UsagePresentationSnapshot?
    public let updatePill: UpdateAvailablePill
    public let isNotificationPeekVisible: Bool
    public let isOnboardingActive: Bool
    public let onboardingStep: OnboardingStep?
    public let hasQuestionSelections: Bool
    public let questionSelectionCount: Int
    public let actionRequestPreviews: [ActionRequestPreview]
    public let manuallyExpandedSessionIDs: Set<String>

    public var rootContentStatus: NotchRootContentStatus {
        presentationState.rootContentStatus
    }

    public init(
        sessions: [AgentSession] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus,
        layoutMode: NotchLayoutMode,
        focusedSessionId: String?,
        presentationState: NotchPresentationState,
        sessionSets: NotchSessionSets,
        contentDimensions: NotchContentDimensions,
        pillSnapshot: PillSnapshot,
        completionUnreadDot: CompletionUnreadDot,
        stateIndicator: StateIndicator,
        usagePresentation: UsagePresentationSnapshot? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        isNotificationPeekVisible: Bool = false,
        isOnboardingActive: Bool = false,
        hasQuestionSelections: Bool = false,
        questionSelectionCount: Int = 0,
        actionRequestPreviews: [ActionRequestPreview] = [],
        manuallyExpandedSessionIDs: Set<String> = []
    ) {
        self.init(
            sessions: sessions,
            originalCompactRuntimeState: originalCompactRuntimeState,
            displayStatus: displayStatus,
            layoutMode: layoutMode,
            focusedSessionId: focusedSessionId,
            presentationState: presentationState,
            sessionSets: sessionSets,
            contentDimensions: contentDimensions,
            pillSnapshot: pillSnapshot,
            completionUnreadDot: completionUnreadDot,
            stateIndicator: stateIndicator,
            usagePresentation: usagePresentation,
            updatePill: updatePill,
            isNotificationPeekVisible: isNotificationPeekVisible,
            isOnboardingActive: isOnboardingActive,
            onboardingStep: nil,
            hasQuestionSelections: hasQuestionSelections,
            questionSelectionCount: questionSelectionCount,
            actionRequestPreviews: actionRequestPreviews,
            manuallyExpandedSessionIDs: manuallyExpandedSessionIDs
        )
    }

    public init(
        sessions: [AgentSession] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus,
        layoutMode: NotchLayoutMode,
        focusedSessionId: String?,
        presentationState: NotchPresentationState,
        sessionSets: NotchSessionSets,
        contentDimensions: NotchContentDimensions,
        pillSnapshot: PillSnapshot,
        completionUnreadDot: CompletionUnreadDot,
        stateIndicator: StateIndicator,
        usagePresentation: UsagePresentationSnapshot? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        isNotificationPeekVisible: Bool = false,
        isOnboardingActive: Bool = false,
        onboardingStep: OnboardingStep?,
        hasQuestionSelections: Bool = false,
        questionSelectionCount: Int = 0,
        actionRequestPreviews: [ActionRequestPreview] = [],
        manuallyExpandedSessionIDs: Set<String> = []
    ) {
        self.sessions = sessions
        self.originalCompactRuntimeState = originalCompactRuntimeState
        self.displayStatus = displayStatus
        self.layoutMode = layoutMode
        self.focusedSessionId = focusedSessionId
        self.presentationState = presentationState
        self.sessionSets = sessionSets
        self.contentDimensions = contentDimensions
        self.pillSnapshot = pillSnapshot
        self.completionUnreadDot = completionUnreadDot
        self.stateIndicator = stateIndicator
        self.usagePresentation = usagePresentation
        self.updatePill = updatePill
        self.isNotificationPeekVisible = isNotificationPeekVisible
        self.isOnboardingActive = isOnboardingActive
        self.onboardingStep = onboardingStep
        self.hasQuestionSelections = hasQuestionSelections
        self.questionSelectionCount = max(0, questionSelectionCount)
        self.actionRequestPreviews = actionRequestPreviews
        self.manuallyExpandedSessionIDs = manuallyExpandedSessionIDs
    }

    public init(state: NotchViewModelState) {
        let presentation = state.overlayState.panelState.presentationState
        let displayStatus = NotchDisplayStatus(displayState: presentation.displayState)
        let layoutMode = NotchLayoutMode(
            displayState: presentation.displayState,
            preferences: state.localPreferences
        )
        let pillSnapshot = presentation.pillSnapshot

        self.init(
            sessions: state.sessions,
            originalCompactRuntimeState: state.originalCompactRuntimeState,
            displayStatus: displayStatus,
            layoutMode: layoutMode,
            focusedSessionId: presentation.focusedSessionId ?? state.focusedSessionId,
            presentationState: presentation,
            sessionSets: NotchSessionSets(state: state),
            contentDimensions: NotchContentDimensions(
                placementPlan: state.overlayState.panelState.placementPlan,
                rootContentStatus: presentation.rootContentStatus
            ),
            pillSnapshot: pillSnapshot,
            completionUnreadDot: CompletionUnreadDot(
                snapshot: pillSnapshot,
                autoExpandOnTaskComplete: state.autoExpandOnTaskComplete,
                completionOverviewSeen: state.completionOverviewSeen,
                quietSceneCompletionPending: state.quietSceneCompletionPending
            ),
            stateIndicator: StateIndicator(snapshot: pillSnapshot),
            usagePresentation: state.usagePresentation,
            isNotificationPeekVisible: presentation.displayState == .notificationPeek
                && !presentation.notificationPreviews.isEmpty,
            isOnboardingActive: state.onboardingState != nil
                || presentation.interactionState.onboardingActive,
            onboardingStep: state.onboardingState?.currentStep,
            hasQuestionSelections: !state.questionSelections.selections.isEmpty,
            questionSelectionCount: state.questionSelections.selections.count,
            actionRequestPreviews: state.actionRequestPreviews,
            manuallyExpandedSessionIDs: state.manuallyExpandedSessionIDs
        )
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessions: try container.decodeIfPresent([AgentSession].self, forKey: .sessions) ?? [],
            originalCompactRuntimeState: try container.decodeIfPresent(
                OriginalCompactRuntimeState.self,
                forKey: .originalCompactRuntimeState
            ) ?? OriginalCompactRuntimeState(),
            displayStatus: try container.decode(NotchDisplayStatus.self, forKey: .displayStatus),
            layoutMode: try container.decode(NotchLayoutMode.self, forKey: .layoutMode),
            focusedSessionId: try container.decodeIfPresent(String.self, forKey: .focusedSessionId),
            presentationState: try container.decode(NotchPresentationState.self, forKey: .presentationState),
            sessionSets: try container.decode(NotchSessionSets.self, forKey: .sessionSets),
            contentDimensions: try container.decode(NotchContentDimensions.self, forKey: .contentDimensions),
            pillSnapshot: try container.decode(PillSnapshot.self, forKey: .pillSnapshot),
            completionUnreadDot: try container.decode(CompletionUnreadDot.self, forKey: .completionUnreadDot),
            stateIndicator: try container.decode(StateIndicator.self, forKey: .stateIndicator),
            usagePresentation: try container.decodeIfPresent(UsagePresentationSnapshot.self, forKey: .usagePresentation),
            updatePill: try container.decode(UpdateAvailablePill.self, forKey: .updatePill),
            isNotificationPeekVisible: try container.decode(Bool.self, forKey: .isNotificationPeekVisible),
            isOnboardingActive: try container.decode(Bool.self, forKey: .isOnboardingActive),
            onboardingStep: try container.decodeIfPresent(OnboardingStep.self, forKey: .onboardingStep),
            hasQuestionSelections: try container.decode(Bool.self, forKey: .hasQuestionSelections),
            questionSelectionCount: try container.decode(Int.self, forKey: .questionSelectionCount),
            actionRequestPreviews: try container.decodeIfPresent(
                [ActionRequestPreview].self,
                forKey: .actionRequestPreviews
            ) ?? [],
            manuallyExpandedSessionIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .manuallyExpandedSessionIDs
            ) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case originalCompactRuntimeState
        case displayStatus
        case layoutMode
        case focusedSessionId
        case presentationState
        case sessionSets
        case contentDimensions
        case pillSnapshot
        case completionUnreadDot
        case stateIndicator
        case usagePresentation
        case updatePill
        case isNotificationPeekVisible
        case isOnboardingActive
        case onboardingStep
        case hasQuestionSelections
        case questionSelectionCount
        case actionRequestPreviews
        case manuallyExpandedSessionIDs
    }
}

public enum IslandSurfaceSection: String, Codable, Equatable, Sendable {
    case compactPill
    case expandedPanel
    case sessionCards
    case notificationPeek
    case usageInfo
    case updatePill
    case switcher
    case onboardingGlow
    case questionActions
    case actionRequests
}

public struct IslandSurfaceSections: Codable, Equatable, Sendable {
    public let visibleSections: [IslandSurfaceSection]
    public let sessions: [AgentSession]
    public let originalCompactRuntimeState: OriginalCompactRuntimeState
    public let displayStatus: NotchDisplayStatus
    public let rootContentStatus: NotchRootContentStatus
    public let displayReason: DisplayIntentReason
    public let isPreviewingCompletionCard: Bool
    public let completionPreviewSessionID: String?
    public let completionPreview: SessionCardPreview?
    public let completionPreviewSession: AgentSession?
    public let layoutMode: NotchLayoutMode
    public let isHovering: Bool
    public let safeAreaAdjustment: Double
    public let isCompletionUnreadOverviewVisible: Bool
    public let primarySessionIds: [String]
    public let notificationSessionIds: [String]
    public let focusedSessionId: String?
    public let contentSize: DisplaySize
    public let rightSlotContent: PillRightSlotContent
    public let usageInfoBar: UsageInfoBar?
    public let updatePill: UpdateAvailablePill
    public let onboardingStep: OnboardingStep?
    public let questionSelectionCount: Int
    public let actionRequestPreviews: [ActionRequestPreview]
    public let manuallyExpandedSessionIDs: Set<String>

    public init(
        visibleSections: [IslandSurfaceSection] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        displayReason: DisplayIntentReason = .none,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil,
        layoutMode: NotchLayoutMode = .regular,
        isHovering: Bool = false,
        safeAreaAdjustment: Double = 0,
        isCompletionUnreadOverviewVisible: Bool = false,
        primarySessionIds: [String] = [],
        notificationSessionIds: [String] = [],
        focusedSessionId: String? = nil,
        contentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        rightSlotContent: PillRightSlotContent = .none,
        usageInfoBar: UsageInfoBar? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        questionSelectionCount: Int = 0,
        actionRequestPreviews: [ActionRequestPreview] = [],
        manuallyExpandedSessionIDs: Set<String> = []
    ) {
        self.init(
            visibleSections: visibleSections,
            originalCompactRuntimeState: originalCompactRuntimeState,
            displayStatus: displayStatus,
            rootContentStatus: rootContentStatus,
            displayReason: displayReason,
            isPreviewingCompletionCard: isPreviewingCompletionCard,
            completionPreviewSessionID: completionPreviewSessionID,
            completionPreview: completionPreview,
            completionPreviewSession: completionPreviewSession,
            layoutMode: layoutMode,
            isHovering: isHovering,
            safeAreaAdjustment: safeAreaAdjustment,
            isCompletionUnreadOverviewVisible: isCompletionUnreadOverviewVisible,
            onboardingStep: nil,
            primarySessionIds: primarySessionIds,
            notificationSessionIds: notificationSessionIds,
            focusedSessionId: focusedSessionId,
            contentSize: contentSize,
            rightSlotContent: rightSlotContent,
            usageInfoBar: usageInfoBar,
            updatePill: updatePill,
            questionSelectionCount: questionSelectionCount,
            actionRequestPreviews: actionRequestPreviews,
            manuallyExpandedSessionIDs: manuallyExpandedSessionIDs
        )
    }

    public init(
        visibleSections: [IslandSurfaceSection] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        displayReason: DisplayIntentReason = .none,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil,
        layoutMode: NotchLayoutMode = .regular,
        isHovering: Bool = false,
        safeAreaAdjustment: Double = 0,
        isCompletionUnreadOverviewVisible: Bool = false,
        onboardingStep: OnboardingStep?,
        primarySessionIds: [String] = [],
        notificationSessionIds: [String] = [],
        focusedSessionId: String? = nil,
        contentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        rightSlotContent: PillRightSlotContent = .none,
        usageInfoBar: UsageInfoBar? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        questionSelectionCount: Int = 0,
        actionRequestPreviews: [ActionRequestPreview] = [],
        manuallyExpandedSessionIDs: Set<String> = []
    ) {
        self.init(
            sessions: [],
            visibleSections: visibleSections,
            originalCompactRuntimeState: originalCompactRuntimeState,
            displayStatus: displayStatus,
            rootContentStatus: rootContentStatus,
            displayReason: displayReason,
            isPreviewingCompletionCard: isPreviewingCompletionCard,
            completionPreviewSessionID: completionPreviewSessionID,
            completionPreview: completionPreview,
            completionPreviewSession: completionPreviewSession,
            layoutMode: layoutMode,
            isHovering: isHovering,
            safeAreaAdjustment: safeAreaAdjustment,
            isCompletionUnreadOverviewVisible: isCompletionUnreadOverviewVisible,
            onboardingStep: onboardingStep,
            primarySessionIds: primarySessionIds,
            notificationSessionIds: notificationSessionIds,
            focusedSessionId: focusedSessionId,
            contentSize: contentSize,
            rightSlotContent: rightSlotContent,
            usageInfoBar: usageInfoBar,
            updatePill: updatePill,
            questionSelectionCount: questionSelectionCount,
            actionRequestPreviews: actionRequestPreviews,
            manuallyExpandedSessionIDs: manuallyExpandedSessionIDs
        )
    }

    public init(
        sessions: [AgentSession],
        visibleSections: [IslandSurfaceSection] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        displayReason: DisplayIntentReason = .none,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil,
        layoutMode: NotchLayoutMode = .regular,
        isHovering: Bool = false,
        safeAreaAdjustment: Double = 0,
        isCompletionUnreadOverviewVisible: Bool = false,
        onboardingStep: OnboardingStep?,
        primarySessionIds: [String] = [],
        notificationSessionIds: [String] = [],
        focusedSessionId: String? = nil,
        contentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        rightSlotContent: PillRightSlotContent = .none,
        usageInfoBar: UsageInfoBar? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        questionSelectionCount: Int = 0,
        actionRequestPreviews: [ActionRequestPreview] = [],
        manuallyExpandedSessionIDs: Set<String> = []
    ) {
        self.visibleSections = Self.unique(visibleSections)
        self.sessions = sessions
        self.originalCompactRuntimeState = originalCompactRuntimeState
        self.displayStatus = displayStatus
        self.rootContentStatus = rootContentStatus ?? NotchRootContentStatus(displayStatus: displayStatus)
        self.displayReason = displayReason
        self.isPreviewingCompletionCard = isPreviewingCompletionCard
        self.completionPreviewSessionID = completionPreviewSessionID
        self.completionPreview = completionPreview
        self.completionPreviewSession = completionPreviewSession
        self.layoutMode = layoutMode
        self.isHovering = isHovering
        self.safeAreaAdjustment = max(0, safeAreaAdjustment)
        self.isCompletionUnreadOverviewVisible = isCompletionUnreadOverviewVisible
        self.primarySessionIds = primarySessionIds
        self.notificationSessionIds = notificationSessionIds
        self.focusedSessionId = focusedSessionId
        self.contentSize = contentSize
        self.rightSlotContent = rightSlotContent
        self.usageInfoBar = usageInfoBar
        self.updatePill = updatePill
        self.onboardingStep = onboardingStep
        self.questionSelectionCount = max(0, questionSelectionCount)
        self.actionRequestPreviews = actionRequestPreviews
        self.manuallyExpandedSessionIDs = manuallyExpandedSessionIDs
    }

    public init(
        visibleSections: [IslandSurfaceSection] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        displayReason: DisplayIntentReason = .none,
        layoutMode: NotchLayoutMode = .regular,
        isHovering: Bool = false,
        safeAreaAdjustment: Double = 0,
        isCompletionUnreadOverviewVisible: Bool = false,
        primarySessionIds: [String] = [],
        notificationSessionIds: [String] = [],
        focusedSessionId: String? = nil,
        contentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        rightSlotContent: PillRightSlotContent = .none,
        usageInfoBar: UsageInfoBar? = nil,
        updatePill: UpdateAvailablePill = UpdateAvailablePill(),
        actionRequestPreviews: [ActionRequestPreview] = []
    ) {
        self.init(
            visibleSections: visibleSections,
            originalCompactRuntimeState: originalCompactRuntimeState,
            displayStatus: displayStatus,
            rootContentStatus: rootContentStatus,
            displayReason: displayReason,
            layoutMode: layoutMode,
            isHovering: isHovering,
            safeAreaAdjustment: safeAreaAdjustment,
            isCompletionUnreadOverviewVisible: isCompletionUnreadOverviewVisible,
            primarySessionIds: primarySessionIds,
            notificationSessionIds: notificationSessionIds,
            focusedSessionId: focusedSessionId,
            contentSize: contentSize,
            rightSlotContent: rightSlotContent,
            usageInfoBar: usageInfoBar,
            updatePill: updatePill,
            questionSelectionCount: 0,
            actionRequestPreviews: actionRequestPreviews
        )
    }

    public init(surface: IslandSurfaceSnapshot) {
        self.init(
            sessions: surface.sessions,
            visibleSections: Self.sections(for: surface),
            originalCompactRuntimeState: surface.originalCompactRuntimeState,
            displayStatus: surface.displayStatus,
            rootContentStatus: surface.rootContentStatus,
            displayReason: surface.presentationState.displayReason,
            isPreviewingCompletionCard: surface.presentationState.isPreviewingCompletionCard,
            completionPreviewSessionID: surface.presentationState.completionPreviewSessionID,
            completionPreview: surface.presentationState.completionPreview,
            completionPreviewSession: surface.presentationState.completionPreviewSession,
            layoutMode: surface.layoutMode,
            isHovering: surface.presentationState.interactionState.isHovering,
            safeAreaAdjustment: surface.contentDimensions.safeAreaAdjustment,
            isCompletionUnreadOverviewVisible: surface.completionUnreadDot.isVisible,
            onboardingStep: surface.onboardingStep,
            primarySessionIds: surface.presentationState.sessionPreviews.map(\.sessionId),
            notificationSessionIds: surface.presentationState.notificationPreviews.map(\.sessionId),
            focusedSessionId: surface.focusedSessionId,
            contentSize: surface.contentDimensions.activeContentSize,
            rightSlotContent: surface.pillSnapshot.rightSlotContent,
            usageInfoBar: surface.pillSnapshot.usageInfoBar,
            updatePill: surface.updatePill,
            questionSelectionCount: surface.questionSelectionCount,
            actionRequestPreviews: surface.actionRequestPreviews,
            manuallyExpandedSessionIDs: surface.manuallyExpandedSessionIDs
        )
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessions: try container.decodeIfPresent([AgentSession].self, forKey: .sessions) ?? [],
            visibleSections: try container.decode([IslandSurfaceSection].self, forKey: .visibleSections),
            originalCompactRuntimeState: try container.decodeIfPresent(
                OriginalCompactRuntimeState.self,
                forKey: .originalCompactRuntimeState
            ) ?? OriginalCompactRuntimeState(),
            displayStatus: try container.decodeIfPresent(NotchDisplayStatus.self, forKey: .displayStatus) ?? .closed,
            rootContentStatus: try container.decodeIfPresent(NotchRootContentStatus.self, forKey: .rootContentStatus),
            displayReason: try container.decodeIfPresent(DisplayIntentReason.self, forKey: .displayReason) ?? .none,
            isPreviewingCompletionCard: try container.decodeIfPresent(Bool.self, forKey: .isPreviewingCompletionCard) ?? false,
            completionPreviewSessionID: try container.decodeIfPresent(String.self, forKey: .completionPreviewSessionID),
            completionPreview: try container.decodeIfPresent(SessionCardPreview.self, forKey: .completionPreview),
            completionPreviewSession: try container.decodeIfPresent(AgentSession.self, forKey: .completionPreviewSession),
            layoutMode: try container.decodeIfPresent(NotchLayoutMode.self, forKey: .layoutMode) ?? .compact,
            isHovering: try container.decodeIfPresent(Bool.self, forKey: .isHovering) ?? false,
            safeAreaAdjustment: try container.decodeIfPresent(Double.self, forKey: .safeAreaAdjustment) ?? 0,
            isCompletionUnreadOverviewVisible: try container.decodeIfPresent(
                Bool.self,
                forKey: .isCompletionUnreadOverviewVisible
            ) ?? false,
            onboardingStep: try container.decodeIfPresent(OnboardingStep.self, forKey: .onboardingStep),
            primarySessionIds: try container.decode([String].self, forKey: .primarySessionIds),
            notificationSessionIds: try container.decode([String].self, forKey: .notificationSessionIds),
            focusedSessionId: try container.decodeIfPresent(String.self, forKey: .focusedSessionId),
            contentSize: try container.decode(DisplaySize.self, forKey: .contentSize),
            rightSlotContent: try container.decode(PillRightSlotContent.self, forKey: .rightSlotContent),
            usageInfoBar: try container.decodeIfPresent(UsageInfoBar.self, forKey: .usageInfoBar),
            updatePill: try container.decode(UpdateAvailablePill.self, forKey: .updatePill),
            questionSelectionCount: try container.decode(Int.self, forKey: .questionSelectionCount),
            actionRequestPreviews: try container.decodeIfPresent(
                [ActionRequestPreview].self,
                forKey: .actionRequestPreviews
            ) ?? [],
            manuallyExpandedSessionIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .manuallyExpandedSessionIDs
            ) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case visibleSections
        case sessions
        case originalCompactRuntimeState
        case displayStatus
        case rootContentStatus
        case displayReason
        case isPreviewingCompletionCard
        case completionPreviewSessionID
        case completionPreview
        case completionPreviewSession
        case layoutMode
        case isHovering
        case safeAreaAdjustment
        case isCompletionUnreadOverviewVisible
        case primarySessionIds
        case notificationSessionIds
        case focusedSessionId
        case contentSize
        case rightSlotContent
        case usageInfoBar
        case updatePill
        case onboardingStep
        case questionSelectionCount
        case actionRequestPreviews
        case manuallyExpandedSessionIDs
    }

    private static func sections(for surface: IslandSurfaceSnapshot) -> [IslandSurfaceSection] {
        var sections: [IslandSurfaceSection] = []

        if surface.displayStatus != .hidden && surface.displayStatus != .autoHidden {
            sections.append(.compactPill)
        }

        if surface.rootContentStatus.usesExpandedContent {
            sections.append(.expandedPanel)
        }

        if !surface.presentationState.sessionPreviews.isEmpty
            && surface.rootContentStatus.usesExpandedContent {
            sections.append(.sessionCards)
        }

        if surface.isNotificationPeekVisible {
            sections.append(.notificationPeek)
        }

        if surface.usagePresentation != nil || surface.pillSnapshot.usageInfoBar != nil {
            sections.append(.usageInfo)
        }

        if surface.updatePill.visible {
            sections.append(.updatePill)
        }

        if surface.displayStatus == .switcher {
            sections.append(.switcher)
        }

        if surface.isOnboardingActive {
            sections.append(.onboardingGlow)
        }

        if surface.hasQuestionSelections || surface.questionSelectionCount > 0 {
            sections.append(.questionActions)
        }

        if !surface.actionRequestPreviews.isEmpty {
            sections.append(.actionRequests)
        }

        return sections
    }

    private static func unique(_ sections: [IslandSurfaceSection]) -> [IslandSurfaceSection] {
        var seen = Set<IslandSurfaceSection>()
        return sections.filter { seen.insert($0).inserted }
    }
}

public struct IslandSurfaceRenderItem: Codable, Equatable, Sendable {
    public let section: IslandSurfaceSection
    public let originalCompactRuntimeState: OriginalCompactRuntimeState
    public let displayStatus: NotchDisplayStatus
    public let layoutMode: NotchLayoutMode
    public let isHovering: Bool
    public let safeAreaAdjustment: Double
    public let isCompletionUnreadOverviewVisible: Bool
    public let sessionIds: [String]
    public let focusedSessionId: String?
    public let contentSize: DisplaySize
    public let interactionHint: IslandSurfaceInteractionHint
    public let actionRequestPreviews: [ActionRequestPreview]
    public let sessionPreviews: [SessionCardPreview]?
    public let sessions: [AgentSession]

    public init(
        section: IslandSurfaceSection,
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        displayStatus: NotchDisplayStatus = .closed,
        layoutMode: NotchLayoutMode = .regular,
        isHovering: Bool = false,
        safeAreaAdjustment: Double = 0,
        isCompletionUnreadOverviewVisible: Bool = false,
        sessionIds: [String] = [],
        focusedSessionId: String? = nil,
        contentSize: DisplaySize = DisplaySize(width: 0, height: 0),
        interactionHint: IslandSurfaceInteractionHint? = nil,
        actionRequestPreviews: [ActionRequestPreview] = [],
        sessionPreviews: [SessionCardPreview]? = nil,
        sessions: [AgentSession] = []
    ) {
        self.section = section
        self.originalCompactRuntimeState = originalCompactRuntimeState
        self.displayStatus = displayStatus
        self.layoutMode = layoutMode
        self.isHovering = isHovering
        self.safeAreaAdjustment = max(0, safeAreaAdjustment)
        self.isCompletionUnreadOverviewVisible = isCompletionUnreadOverviewVisible
        self.sessionIds = sessionIds
        self.focusedSessionId = focusedSessionId
        self.contentSize = contentSize
        self.interactionHint = interactionHint ?? IslandSurfaceInteractionHint(section: section)
        self.actionRequestPreviews = actionRequestPreviews
        self.sessionPreviews = sessionPreviews
        self.sessions = sessions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            section: try container.decode(IslandSurfaceSection.self, forKey: .section),
            originalCompactRuntimeState: try container.decodeIfPresent(
                OriginalCompactRuntimeState.self,
                forKey: .originalCompactRuntimeState
            ) ?? OriginalCompactRuntimeState(),
            displayStatus: try container.decodeIfPresent(NotchDisplayStatus.self, forKey: .displayStatus) ?? .closed,
            layoutMode: try container.decodeIfPresent(NotchLayoutMode.self, forKey: .layoutMode) ?? .compact,
            isHovering: try container.decodeIfPresent(Bool.self, forKey: .isHovering) ?? false,
            safeAreaAdjustment: try container.decodeIfPresent(Double.self, forKey: .safeAreaAdjustment) ?? 0,
            isCompletionUnreadOverviewVisible: try container.decodeIfPresent(
                Bool.self,
                forKey: .isCompletionUnreadOverviewVisible
            ) ?? false,
            sessionIds: try container.decode([String].self, forKey: .sessionIds),
            focusedSessionId: try container.decodeIfPresent(String.self, forKey: .focusedSessionId),
            contentSize: try container.decode(DisplaySize.self, forKey: .contentSize),
            interactionHint: try container.decode(IslandSurfaceInteractionHint.self, forKey: .interactionHint),
            actionRequestPreviews: try container.decodeIfPresent(
                [ActionRequestPreview].self,
                forKey: .actionRequestPreviews
            ) ?? [],
            sessionPreviews: try container.decodeIfPresent([SessionCardPreview].self, forKey: .sessionPreviews),
            sessions: try container.decodeIfPresent([AgentSession].self, forKey: .sessions) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case section
        case originalCompactRuntimeState
        case displayStatus
        case layoutMode
        case isHovering
        case safeAreaAdjustment
        case isCompletionUnreadOverviewVisible
        case sessionIds
        case focusedSessionId
        case contentSize
        case interactionHint
        case actionRequestPreviews
        case sessionPreviews
        case sessions
    }
}

public enum IslandSurfaceInteractionHint: String, Codable, Equatable, Sendable {
    case none
    case toggleExpandedPanel
    case openFocusedSession
    case openNotificationSession
    case openUpdateWindow
    case switchFocusedSession
    case answerQuestion

    public init(section: IslandSurfaceSection) {
        switch section {
        case .compactPill:
            self = .toggleExpandedPanel
        case .expandedPanel, .sessionCards:
            self = .openFocusedSession
        case .notificationPeek:
            self = .openNotificationSession
        case .updatePill:
            self = .openUpdateWindow
        case .switcher:
            self = .switchFocusedSession
        case .questionActions:
            self = .answerQuestion
        case .usageInfo, .onboardingGlow, .actionRequests:
            self = .none
        }
    }
}

public struct IslandSurfaceRenderList: Codable, Equatable, Sendable {
    private static let compactDisplaySessionLimit = 10

    public let sections: IslandSurfaceSections
    public let items: [IslandSurfaceRenderItem]

    public init(sections: IslandSurfaceSections) {
        self.sections = sections
        items = sections.visibleSections.map { section in
            let sessionIds = Self.sessionIds(for: section, in: sections)
            let sessionIdSet = Set(sessionIds)
            return IslandSurfaceRenderItem(
                section: section,
                originalCompactRuntimeState: sections.originalCompactRuntimeState,
                displayStatus: sections.displayStatus,
                layoutMode: sections.layoutMode,
                isHovering: sections.isHovering,
                safeAreaAdjustment: sections.safeAreaAdjustment,
                isCompletionUnreadOverviewVisible: sections.isCompletionUnreadOverviewVisible,
                sessionIds: sessionIds,
                focusedSessionId: sections.focusedSessionId,
                contentSize: sections.contentSize,
                actionRequestPreviews: section == .actionRequests ? sections.actionRequestPreviews : [],
                sessions: Self.sessions(for: section, sections: sections, sessionIdSet: sessionIdSet)
            )
        }
    }

    public init(surface: IslandSurfaceSnapshot) {
        let sections = IslandSurfaceSections(surface: surface)
        self.sections = sections
        items = sections.visibleSections.map { section in
            let sessionIds = Self.sessionIds(for: section, in: sections)
            let sessionIdSet = Set(sessionIds)
            let candidatePreviews = section == .notificationPeek
                ? surface.presentationState.notificationPreviews
                : surface.presentationState.sessionPreviews
            return IslandSurfaceRenderItem(
                section: section,
                originalCompactRuntimeState: sections.originalCompactRuntimeState,
                displayStatus: sections.displayStatus,
                layoutMode: sections.layoutMode,
                isHovering: sections.isHovering,
                safeAreaAdjustment: sections.safeAreaAdjustment,
                isCompletionUnreadOverviewVisible: sections.isCompletionUnreadOverviewVisible,
                sessionIds: sessionIds,
                focusedSessionId: sections.focusedSessionId,
                contentSize: sections.contentSize,
                actionRequestPreviews: section == .actionRequests ? sections.actionRequestPreviews : [],
                sessionPreviews: candidatePreviews.filter {
                    sessionIdSet.contains($0.sessionId)
                },
                sessions: Self.sessions(for: section, sections: sections, sessionIdSet: sessionIdSet)
            )
        }
    }

    private static func sessions(
        for section: IslandSurfaceSection,
        sections: IslandSurfaceSections,
        sessionIdSet: Set<String>
    ) -> [AgentSession] {
        if section == .compactPill, sessionIdSet.count >= compactDisplaySessionLimit {
            return sections.sessions
        }
        return sections.sessions.filter { sessionIdSet.contains($0.id) }
    }

    private static func sessionIds(
        for section: IslandSurfaceSection,
        in sections: IslandSurfaceSections
    ) -> [String] {
        switch section {
        case .notificationPeek:
            return sections.notificationSessionIds
        case .actionRequests:
            return sections.actionRequestPreviews.map(\.sessionId)
        case .compactPill:
            return sections.primarySessionIds
        case .expandedPanel, .sessionCards, .usageInfo, .updatePill,
             .switcher, .onboardingGlow, .questionActions:
            // SessionsListView consumes the Store-owned derived SessionState
            // collection. Presentation previews are an enrichment channel and
            // may lag one publication behind; they must not reduce the rows
            // supplied to the expanded list.
            return sections.sessions.isEmpty
                ? sections.primarySessionIds
                : sections.sessions.map(\.id)
        }
    }
}

public struct NotchViewModelState: Codable, Equatable, Sendable {
    public let sessions: [AgentSession]
    public let originalCompactRuntimeState: OriginalCompactRuntimeState
    public let sessionPreviews: [SessionCardPreview]
    public let actionRequestPreviews: [ActionRequestPreview]
    public let focusedSessionId: String?
    public let overlayState: OverlayControllerState
    public let usagePresentation: UsagePresentationSnapshot?
    public let onboardingState: OnboardingState?
    public let onboardingDemoState: OnboardingDemoRunnerState?
    public let questionSelections: QuestionSelectionState
    public let notificationPreviews: [SessionCardPreview]
    public let localPreferences: NotchLocalUIPreferences
    public let manuallyExpandedSessionIDs: Set<String>
    public let autoExpandOnTaskComplete: Bool
    public let completionOverviewSeen: Bool
    public let quietSceneCompletionPending: Bool

    public init(
        sessions: [AgentSession] = [],
        originalCompactRuntimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
        sessionPreviews: [SessionCardPreview] = [],
        actionRequestPreviews: [ActionRequestPreview] = [],
        focusedSessionId: String? = nil,
        overlayState: OverlayControllerState = OverlayControllerState(),
        usagePresentation: UsagePresentationSnapshot? = nil,
        onboardingState: OnboardingState? = nil,
        onboardingDemoState: OnboardingDemoRunnerState? = nil,
        questionSelections: QuestionSelectionState = QuestionSelectionState(),
        notificationPreviews: [SessionCardPreview] = [],
        localPreferences: NotchLocalUIPreferences = NotchLocalUIPreferences(),
        manuallyExpandedSessionIDs: Set<String> = [],
        autoExpandOnTaskComplete: Bool = true,
        completionOverviewSeen: Bool = false,
        quietSceneCompletionPending: Bool = false
    ) {
        self.sessions = sessions
        self.originalCompactRuntimeState = originalCompactRuntimeState
        self.sessionPreviews = sessionPreviews
        self.actionRequestPreviews = actionRequestPreviews
        self.focusedSessionId = focusedSessionId
        self.overlayState = overlayState
        self.usagePresentation = usagePresentation
        self.onboardingState = onboardingState
        self.onboardingDemoState = onboardingDemoState
        self.questionSelections = questionSelections
        self.notificationPreviews = notificationPreviews
        self.localPreferences = localPreferences
        self.manuallyExpandedSessionIDs = manuallyExpandedSessionIDs
        self.autoExpandOnTaskComplete = autoExpandOnTaskComplete
        self.completionOverviewSeen = completionOverviewSeen
        self.quietSceneCompletionPending = quietSceneCompletionPending
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessions: try container.decodeIfPresent([AgentSession].self, forKey: .sessions) ?? [],
            originalCompactRuntimeState: try container.decodeIfPresent(
                OriginalCompactRuntimeState.self,
                forKey: .originalCompactRuntimeState
            ) ?? OriginalCompactRuntimeState(),
            sessionPreviews: try container.decode([SessionCardPreview].self, forKey: .sessionPreviews),
            actionRequestPreviews: try container.decodeIfPresent(
                [ActionRequestPreview].self,
                forKey: .actionRequestPreviews
            ) ?? [],
            focusedSessionId: try container.decodeIfPresent(String.self, forKey: .focusedSessionId),
            overlayState: try container.decode(OverlayControllerState.self, forKey: .overlayState),
            usagePresentation: try container.decodeIfPresent(UsagePresentationSnapshot.self, forKey: .usagePresentation),
            onboardingState: try container.decodeIfPresent(OnboardingState.self, forKey: .onboardingState),
            onboardingDemoState: try container.decodeIfPresent(OnboardingDemoRunnerState.self, forKey: .onboardingDemoState),
            questionSelections: try container.decode(QuestionSelectionState.self, forKey: .questionSelections),
            notificationPreviews: try container.decode([SessionCardPreview].self, forKey: .notificationPreviews),
            localPreferences: try container.decode(NotchLocalUIPreferences.self, forKey: .localPreferences),
            manuallyExpandedSessionIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .manuallyExpandedSessionIDs
            ) ?? [],
            autoExpandOnTaskComplete: try container.decodeIfPresent(
                Bool.self,
                forKey: .autoExpandOnTaskComplete
            ) ?? true,
            completionOverviewSeen: try container.decodeIfPresent(
                Bool.self,
                forKey: .completionOverviewSeen
            ) ?? false,
            quietSceneCompletionPending: try container.decodeIfPresent(
                Bool.self,
                forKey: .quietSceneCompletionPending
            ) ?? false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case originalCompactRuntimeState
        case sessionPreviews
        case actionRequestPreviews
        case focusedSessionId
        case overlayState
        case usagePresentation
        case onboardingState
        case onboardingDemoState
        case questionSelections
        case notificationPreviews
        case localPreferences
        case manuallyExpandedSessionIDs
        case autoExpandOnTaskComplete
        case completionOverviewSeen
        case quietSceneCompletionPending
    }
}

public enum NotchViewModelCommand: Equatable, Sendable {
    case synchronizePlacement(DisplayPlacementPlan)
    case toggleExpanded
    case panelInteraction(PanelInteractionCommand)
    case replaceSessions([AgentSession])
    case replaceSessionPreviews([SessionCardPreview])
    case replaceActionRequestPreviews([ActionRequestPreview])
    case replaceRuntimeSnapshot(IslandRuntimeSnapshot)
    case focusSession(String)
    case clearFocus
    case applyUsagePresentation(UsagePresentationSnapshot)
    case consumeTaskCompletion(
        sessionId: String,
        autoExpandOnTaskComplete: Bool,
        quietSceneActive: Bool
    )
    case consumeV3TaskCompletion(V3TaskCompletionInput)
    case showCompletionRender(sessionId: String)
    case showNotificationPeek([SessionCardPreview])
    case clearNotificationPeek
    case applyOnboardingState(OnboardingState)
    case applyOnboardingDemoState(OnboardingDemoRunnerState)
    case recordQuestionSelection(requestId: String, sessionId: String, selection: String)
    case replaceLocalPreferences(NotchLocalUIPreferences)
    case replaceOriginalCompactRuntimeState(OriginalCompactRuntimeState)
    case setQuietSceneCompletionPending(Bool)
    case toggleManualSessionExpansion(sessionID: String)
}

public enum NotchViewModelAction: Equatable, Sendable {
    case overlay(OverlayControllerAction)
    case refreshUsageDisplay
    case showNotificationPeek([SessionCardPreview])
    case clearNotificationPeek
    case storeQuestionSelection(requestId: String, selection: String)
}

public struct NotchViewModelPlan: Equatable, Sendable {
    public let nextState: NotchViewModelState
    public let actions: [NotchViewModelAction]

    public init(nextState: NotchViewModelState, actions: [NotchViewModelAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct NotchViewModelReducer: Sendable {
    public let presentationBuilder: NotchPresentationBuilder
    public let overlayController: OverlayControllerModel

    public init(
        presentationBuilder: NotchPresentationBuilder = NotchPresentationBuilder(),
        overlayController: OverlayControllerModel = OverlayControllerModel()
    ) {
        self.presentationBuilder = presentationBuilder
        self.overlayController = overlayController
    }

    public func reduce(
        _ command: NotchViewModelCommand,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        switch command {
        case let .synchronizePlacement(placement):
            let overlayPlan = overlayController.plan(
                .panelPlacementChanged(placement),
                from: state.overlayState
            )
            return NotchViewModelPlan(
                nextState: replacing(state, overlayState: overlayPlan.nextState),
                actions: overlayPlan.actions.map(NotchViewModelAction.overlay)
            )
        case .toggleExpanded:
            let overlayPlan = overlayController.plan(
                .panelInteraction(.toggleExpanded),
                from: state.overlayState
            )
            let nextState = replacing(state, overlayState: overlayPlan.nextState)
            return NotchViewModelPlan(
                nextState: nextState,
                actions: overlayPlan.actions.map(NotchViewModelAction.overlay) + [
                    .overlay(.renderIslandSurface(
                        IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                    )),
                ]
            )
        case let .panelInteraction(command):
            let overlayPlan = overlayController.plan(
                .panelInteraction(command),
                from: state.overlayState
            )
            let nextOverlayState = expandingHoverPresentation(
                for: command,
                overlayState: overlayPlan.nextState,
                state: state
            )
            let nextState = replacing(
                state,
                overlayState: nextOverlayState,
                completionOverviewSeen: completionOverviewSeen(
                    after: command,
                    previousState: state,
                    nextOverlayState: nextOverlayState
                ),
                quietSceneCompletionPending: quietSceneCompletionPending(
                    after: command,
                    previousState: state,
                    nextOverlayState: nextOverlayState
                )
            )
            let overlayActions = overlayPlan.actions.map { action -> NotchViewModelAction in
                guard case .renderPresentation = action else {
                    return .overlay(action)
                }
                return .overlay(.renderPresentation(
                    nextOverlayState.panelState.presentationState
                ))
            }
            return NotchViewModelPlan(
                nextState: nextState,
                actions: overlayActions + [
                    .overlay(.renderIslandSurface(
                        IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                    )),
                ]
            )
        case let .replaceSessions(sessions):
            return replaceSessions(sessions, state: state)
        case let .replaceSessionPreviews(previews):
            return replaceSessionPreviews(previews, state: state)
        case let .replaceActionRequestPreviews(previews):
            return replaceActionRequestPreviews(previews, state: state)
        case let .replaceRuntimeSnapshot(snapshot):
            return replaceRuntimeSnapshot(snapshot, state: state)
        case let .focusSession(sessionId):
            return focusSession(sessionId, state: state)
        case .clearFocus:
            return replaceFocus(nil, state: state, routeSelection: false)
        case let .applyUsagePresentation(usagePresentation):
            return applyUsagePresentation(usagePresentation, state: state)
        case let .consumeTaskCompletion(sessionId, autoExpandOnTaskComplete, quietSceneActive):
            return consumeTaskCompletion(
                sessionId: sessionId,
                autoExpandOnTaskComplete: autoExpandOnTaskComplete,
                quietSceneActive: quietSceneActive,
                state: state
            )
        case let .consumeV3TaskCompletion(input):
            return consumeV3TaskCompletion(input, state: state)
        case let .showCompletionRender(sessionId):
            return showCompletionRender(sessionId: sessionId, state: state)
        case let .showNotificationPeek(previews):
            return showNotificationPeek(previews, state: state)
        case .clearNotificationPeek:
            return clearNotificationPeek(state: state)
        case let .applyOnboardingState(onboardingState):
            return applyOnboardingState(onboardingState, state: state)
        case let .applyOnboardingDemoState(onboardingDemoState):
            return NotchViewModelPlan(
                nextState: replacing(state, onboardingDemoState: onboardingDemoState),
                actions: []
            )
        case let .recordQuestionSelection(requestId, sessionId, selection):
            return recordQuestionSelection(
                requestId: requestId,
                sessionId: sessionId,
                selection: selection,
                state: state
            )
        case let .replaceLocalPreferences(preferences):
            return NotchViewModelPlan(
                nextState: replacing(state, localPreferences: preferences),
                actions: []
            )
        case let .replaceOriginalCompactRuntimeState(runtimeState):
            let nextState = replacing(state, originalCompactRuntimeState: runtimeState)
            return NotchViewModelPlan(
                nextState: nextState,
                actions: [
                    .overlay(.renderIslandSurface(
                        IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                    )),
                ]
            )
        case let .setQuietSceneCompletionPending(isPending):
            let nextState = replacing(state, quietSceneCompletionPending: isPending)
            return NotchViewModelPlan(
                nextState: nextState,
                actions: [
                    .overlay(.renderIslandSurface(
                        IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                    )),
                ]
            )
        case let .toggleManualSessionExpansion(sessionID):
            var manuallyExpandedSessionIDs = state.manuallyExpandedSessionIDs
            if !manuallyExpandedSessionIDs.insert(sessionID).inserted {
                manuallyExpandedSessionIDs.remove(sessionID)
            }
            let nextState = replacing(
                state,
                manuallyExpandedSessionIDs: manuallyExpandedSessionIDs
            )
            return NotchViewModelPlan(
                nextState: nextState,
                actions: [
                    .overlay(.renderIslandSurface(
                        IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                    )),
                ]
            )
        }
    }

    private func replaceSessions(
        _ sessions: [AgentSession],
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let nextState = replacing(
            state,
            sessions: sessions,
            focusedSessionId: state.focusedSessionId
        )
        return NotchViewModelPlan(
            nextState: nextState,
            actions: [
                .overlay(.renderIslandSurface(
                    IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                )),
            ]
        )
    }

    private func replaceSessionPreviews(
        _ previews: [SessionCardPreview],
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let previousUnreadSessionIDs = Set(
            state.sessionPreviews
                .filter(\.unreadCompletionMarker)
                .map(\.sessionId)
        )
        let hasNewUnreadCompletion = previews.contains {
            $0.unreadCompletionMarker && !previousUnreadSessionIDs.contains($0.sessionId)
        }
        let focusedSessionId = validFocusedSessionId(state.focusedSessionId, in: previews)
        let currentPresentation = state.overlayState.panelState.presentationState
        let retainedCompletionPreview = currentPresentation.completionPreview
            ?? currentPresentation.completionPreviewSessionID.flatMap { id in
                state.sessionPreviews.first { $0.sessionId == id }
            }
        let retainedCompletionPreviewSession = currentPresentation.completionPreviewSession
            ?? retainedCompletionPreview.flatMap { preview in
                state.sessions.first { $0.id == preview.sessionId }
            }
        let retainedCompletionPreviewSessionID = retainedCompletionPreview?.sessionId
        let nextNotificationPreviews = state.notificationPreviews.filter { notification in
            previews.first(where: { $0.sessionId == notification.sessionId })?.unreadCompletionMarker == true
        }
        let presentationPreviews = completionPresentationPreviews(
            fullPreviews: previews,
            presentation: state.overlayState.panelState.presentationState,
            focusedSessionId: focusedSessionId
        )
        let presentation = presentationState(
            displayState: state.overlayState.panelState.presentationState.displayState,
            previews: presentationPreviews,
            focusedSessionId: validFocusedSessionId(focusedSessionId, in: presentationPreviews),
            interactionState: state.overlayState.panelState.presentationState.interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: nextNotificationPreviews,
            displayReason: state.overlayState.panelState.presentationState.displayReason,
            isPreviewingCompletionCard: retainedCompletionPreviewSessionID != nil,
            completionPreviewSessionID: retainedCompletionPreviewSessionID,
            completionPreview: retainedCompletionPreview,
            completionPreviewSession: retainedCompletionPreviewSession
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            sessionPreviews: previews,
            focusedSessionId: state.focusedSessionId,
            overlayState: overlayPlan.nextState,
            notificationPreviews: nextNotificationPreviews,
            completionOverviewSeen: hasNewUnreadCompletion ? false : state.completionOverviewSeen
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: overlayPlan.actions.map(NotchViewModelAction.overlay) + [
                .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
            ]
        )
    }

    private func replaceActionRequestPreviews(
        _ previews: [ActionRequestPreview],
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let currentPresentation = state.overlayState.panelState.presentationState
        let hasLocallyResolvableAction = previews.contains { $0.canResolveLocally }
        let didResolveLastLocallyResolvableAction = currentPresentation.interactionState.blockingActionVisible
            && !hasLocallyResolvableAction
        let displayState: PanelDisplayState = hasLocallyResolvableAction
            ? .expanded
            : currentPresentation.displayState
        let currentInteraction = currentPresentation.interactionState
        let interactionState = PanelInteractionState(
            displayState: displayState,
            rootContentStatus: hasLocallyResolvableAction ? .expanded : currentInteraction.rootContentStatus,
            isPinned: currentInteraction.isPinned,
            isHovering: currentInteraction.isHovering,
            isMouseInMenuBarZone: currentInteraction.isMouseInMenuBarZone,
            isMouseInExpandedPanel: currentInteraction.isMouseInExpandedPanel,
            needsKeyboardFocus: currentInteraction.needsKeyboardFocus,
            autoCollapseGeneration: currentInteraction.autoCollapseGeneration,
            mouseLeaveCollapseGeneration: currentInteraction.mouseLeaveCollapseGeneration,
            expandedSince: currentInteraction.expandedSince,
            hoverCooldownUntil: currentInteraction.hoverCooldownUntil,
            transientRevealDwellSeconds: currentInteraction.transientRevealDwellSeconds,
            blockingActionVisible: hasLocallyResolvableAction,
            onboardingActive: currentInteraction.onboardingActive
        )
        let presentationPreviews = hasLocallyResolvableAction
            ? actionRequestPromotedPreviews(
                state.sessionPreviews,
                actionRequests: previews
            )
            : completionPresentationPreviews(
                fullPreviews: state.sessionPreviews,
                presentation: currentPresentation,
                focusedSessionId: state.focusedSessionId
            )
        let focusedSessionId = previews.lazy
            .map(\.sessionId)
            .first { requestSessionID in
                presentationPreviews.contains { $0.sessionId == requestSessionID }
            }
            ?? validFocusedSessionId(state.focusedSessionId, in: presentationPreviews)
        let presentation = presentationState(
            displayState: displayState,
            previews: presentationPreviews,
            focusedSessionId: focusedSessionId,
            interactionState: interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: state.notificationPreviews,
            displayReason: hasLocallyResolvableAction ? .blockingAction : currentPresentation.displayReason,
            isPreviewingCompletionCard: !hasLocallyResolvableAction
                && currentPresentation.isPreviewingCompletionCard,
            completionPreviewSessionID: hasLocallyResolvableAction
                ? nil
                : currentPresentation.completionPreviewSessionID,
            completionPreview: hasLocallyResolvableAction
                ? nil
                : currentPresentation.completionPreview,
            completionPreviewSession: hasLocallyResolvableAction
                ? nil
                : currentPresentation.completionPreviewSession
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )
        let mouseLeavePlan: OverlayControllerPlan?
        if didResolveLastLocallyResolvableAction,
           !interactionState.isMouseInExpandedPanel {
            mouseLeavePlan = overlayController.plan(
                .panelInteraction(.setExpandedPanelHover(false)),
                from: overlayPlan.nextState
            )
        } else {
            mouseLeavePlan = nil
        }
        let nextState = replacing(
            state,
            actionRequestPreviews: previews,
            focusedSessionId: focusedSessionId,
            overlayState: mouseLeavePlan?.nextState ?? overlayPlan.nextState
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: overlayPlan.actions.map(NotchViewModelAction.overlay)
                + (mouseLeavePlan?.actions.map(NotchViewModelAction.overlay) ?? []) + [
                .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
            ]
        )
    }

    private func replaceRuntimeSnapshot(
        _ snapshot: IslandRuntimeSnapshot,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        // V3 applies a verified store receipt to NotchViewModel on MainActor,
        // then derives the display eligibility from that same publication.
        // Keep the local full-store snapshot indivisible at the reducer boundary.
        let sessionsState = replacing(
            state,
            sessions: snapshot.sessions,
            focusedSessionId: state.focusedSessionId
        )
        let previewsPlan = replaceSessionPreviews(
            snapshot.sessionPreviews,
            state: sessionsState
        )
        let actionsPlan = replaceActionRequestPreviews(
            snapshot.actionRequestPreviews,
            state: previewsPlan.nextState
        )
        return NotchViewModelPlan(
            nextState: actionsPlan.nextState,
            actions: actionsPlan.actions
        )
    }

    private func actionRequestPromotedPreviews(
        _ previews: [SessionCardPreview],
        actionRequests: [ActionRequestPreview]
    ) -> [SessionCardPreview] {
        let requestSessionIDs = actionRequests.map(\.sessionId)
        let orderedRequestSessionIDs = requestSessionIDs.reduce(into: [String]()) { ids, sessionID in
            guard !ids.contains(sessionID) else { return }
            ids.append(sessionID)
        }
        let promoted = orderedRequestSessionIDs.compactMap { sessionID in
            previews.first { $0.sessionId == sessionID }
        }
        let promotedIDs = Set(promoted.map(\.sessionId))
        return promoted + previews.filter { !promotedIDs.contains($0.sessionId) }
    }

    private func focusSession(
        _ sessionId: String,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        replaceFocus(sessionId, state: state, routeSelection: true)
    }

    private func replaceFocus(
        _ focusedSessionId: String?,
        state: NotchViewModelState,
        routeSelection: Bool
    ) -> NotchViewModelPlan {
        let validFocus = validFocusedSessionId(focusedSessionId, in: state.sessionPreviews)
        let presentation = presentationState(
            displayState: state.overlayState.panelState.presentationState.displayState,
            previews: state.sessionPreviews,
            focusedSessionId: validFocus,
            interactionState: state.overlayState.panelState.presentationState.interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: state.notificationPreviews,
            displayReason: state.overlayState.panelState.presentationState.displayReason,
            isPreviewingCompletionCard: state.overlayState.panelState.presentationState
                .isPreviewingCompletionCard,
            completionPreviewSessionID: state.overlayState.panelState.presentationState
                .completionPreviewSessionID,
            completionPreview: state.overlayState.panelState.presentationState.completionPreview,
            completionPreviewSession: state.overlayState.panelState.presentationState.completionPreviewSession
        )
        let renderPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )
        var overlayState = renderPlan.nextState
        let renderActions = renderPlan.actions.map(NotchViewModelAction.overlay)
        var routeActions: [NotchViewModelAction] = []

        if routeSelection, let validFocus {
            let routePlan = overlayController.plan(
                .sessionGesture(.selectSession(sessionId: validFocus)),
                from: overlayState
            )
            overlayState = routePlan.nextState
            routeActions = routePlan.actions.map(NotchViewModelAction.overlay)
        }

        let nextState = replacing(
            state,
            focusedSessionId: validFocus,
            overlayState: overlayState
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: renderActions + [
                .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
            ] + routeActions
        )
    }

    private func applyUsagePresentation(
        _ usagePresentation: UsagePresentationSnapshot,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let presentation = presentationState(
            displayState: state.overlayState.panelState.presentationState.displayState,
            previews: state.sessionPreviews,
            focusedSessionId: state.focusedSessionId,
            interactionState: state.overlayState.panelState.presentationState.interactionState,
            usagePresentation: usagePresentation,
            notificationPreviews: state.notificationPreviews,
            displayReason: state.overlayState.panelState.presentationState.displayReason,
            isPreviewingCompletionCard: state.overlayState.panelState.presentationState
                .isPreviewingCompletionCard,
            completionPreviewSessionID: state.overlayState.panelState.presentationState
                .completionPreviewSessionID,
            completionPreview: state.overlayState.panelState.presentationState.completionPreview,
            completionPreviewSession: state.overlayState.panelState.presentationState.completionPreviewSession
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            overlayState: overlayPlan.nextState,
            usagePresentation: usagePresentation
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: [.refreshUsageDisplay]
                + overlayPlan.actions.map(NotchViewModelAction.overlay)
                + [
                    .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
                ]
        )
    }

    private func showNotificationPeek(
        _ previews: [SessionCardPreview],
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let presentation = presentationState(
            displayState: .notificationPeek,
            previews: state.sessionPreviews,
            focusedSessionId: state.focusedSessionId,
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            usagePresentation: state.usagePresentation,
            notificationPreviews: previews,
            displayReason: .notificationPeek
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            overlayState: overlayPlan.nextState,
            notificationPreviews: previews
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: [.showNotificationPeek(previews)]
                + overlayPlan.actions.map(NotchViewModelAction.overlay)
                + [
                    .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
                ]
        )
    }

    private func showCompletionRender(
        sessionId: String,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        guard let preview = state.sessionPreviews.first(where: { $0.sessionId == sessionId }) else {
            return NotchViewModelPlan(nextState: state, actions: [])
        }
        let currentInteraction = state.overlayState.panelState.presentationState.interactionState
        let interactionState = PanelInteractionState(
            displayState: .expanded,
            rootContentStatus: .expanded,
            isPinned: currentInteraction.isPinned,
            isHovering: currentInteraction.isHovering,
            isMouseInMenuBarZone: currentInteraction.isMouseInMenuBarZone,
            isMouseInExpandedPanel: currentInteraction.isMouseInExpandedPanel,
            needsKeyboardFocus: currentInteraction.needsKeyboardFocus,
            autoCollapseGeneration: currentInteraction.autoCollapseGeneration,
            mouseLeaveCollapseGeneration: currentInteraction.mouseLeaveCollapseGeneration,
            expandedSince: currentInteraction.expandedSince,
            hoverCooldownUntil: currentInteraction.hoverCooldownUntil,
            transientRevealDwellSeconds: currentInteraction.transientRevealDwellSeconds,
            blockingActionVisible: currentInteraction.blockingActionVisible,
            onboardingActive: currentInteraction.onboardingActive
        )

        let presentation = presentationState(
            displayState: .expanded,
            previews: state.sessionPreviews,
            focusedSessionId: preview.sessionId,
            interactionState: interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: [preview],
            displayReason: .taskComplete,
            isPreviewingCompletionCard: true,
            completionPreviewSessionID: preview.sessionId,
            completionPreview: preview,
            completionPreviewSession: completionPreviewSession(for: preview, state: state)
        )
        let presentationOverlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )
        let overlayPlan: OverlayControllerPlan
        if interactionState.blockingActionVisible {
            overlayPlan = presentationOverlayPlan
        } else {
            overlayPlan = overlayController.plan(
                .panelInteraction(.transientReveal(kind: .taskComplete, displayState: .expanded)),
                from: presentationOverlayPlan.nextState
            )
        }
        let nextState = replacing(
            state,
            focusedSessionId: preview.sessionId,
            overlayState: overlayPlan.nextState,
            notificationPreviews: [preview]
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: presentationOverlayPlan.actions.map(NotchViewModelAction.overlay)
                + (interactionState.blockingActionVisible
                    ? []
                    : overlayPlan.actions.map(NotchViewModelAction.overlay)) + [
                .overlay(.renderIslandSurface(
                    IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))
                )),
            ]
        )
    }

    private func consumeTaskCompletion(
        sessionId: String,
        autoExpandOnTaskComplete: Bool,
        quietSceneActive: Bool,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        guard state.sessionPreviews.contains(where: { $0.sessionId == sessionId }) else {
            return NotchViewModelPlan(nextState: state, actions: [])
        }
        if autoExpandOnTaskComplete, quietSceneActive {
            return reduce(.setQuietSceneCompletionPending(true), state: state)
        }
        guard autoExpandOnTaskComplete else {
            let runtime = state.originalCompactRuntimeState
            return reduce(
                .replaceOriginalCompactRuntimeState(OriginalCompactRuntimeState(
                    isMinimized: runtime.isMinimized,
                    notchWidthOffset: runtime.notchWidthOffset,
                    notchHeightOffset: runtime.notchHeightOffset,
                    completionFlashTick: runtime.completionFlashTick + 1
                )),
                state: state
            )
        }
        return showCompletionRender(sessionId: sessionId, state: state)
    }

    private func consumeV3TaskCompletion(
        _ input: V3TaskCompletionInput,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        switch V3TaskCompletionConsumer.plan(input) {
        case .suppressed, .leaveAcceptedDecisionUnconsumed:
            return NotchViewModelPlan(nextState: state, actions: [])
        case .markQuietScenePending:
            return reduce(.setQuietSceneCompletionPending(true), state: state)
        case .incrementCompletionFlash:
            let runtime = state.originalCompactRuntimeState
            return reduce(
                .replaceOriginalCompactRuntimeState(OriginalCompactRuntimeState(
                    isMinimized: runtime.isMinimized,
                    notchWidthOffset: runtime.notchWidthOffset,
                    notchHeightOffset: runtime.notchHeightOffset,
                    completionFlashTick: runtime.completionFlashTick + 1
                )),
                state: state
            )
        case let .consumeDecision(decision):
            guard decision.accepted,
                  decision.expansion == .expand,
                  case let .set(sessionId) = decision.activeSessionId,
                  let sessionId else {
                return NotchViewModelPlan(nextState: state, actions: [])
            }
            return showCompletionRender(sessionId: sessionId, state: state)
        }
    }

    private func completionPresentationPreviews(
        fullPreviews: [SessionCardPreview],
        presentation: NotchPresentationState,
        focusedSessionId: String?
    ) -> [SessionCardPreview] {
        fullPreviews
    }

    private func expandingHoverPresentation(
        for command: PanelInteractionCommand,
        overlayState: OverlayControllerState,
        state: NotchViewModelState
    ) -> OverlayControllerState {
        guard overlayState.panelState.presentationState.displayState == .expanded,
              overlayState.panelState.presentationState.displayReason == .userHover else {
            return overlayState
        }

        switch command {
        case .hoverRevealTick, .setExpandedPanelHover(true):
            break
        default:
            return overlayState
        }

        let currentPresentation = overlayState.panelState.presentationState
        let presentation = presentationState(
            displayState: currentPresentation.displayState,
            previews: state.sessionPreviews,
            focusedSessionId: state.focusedSessionId,
            interactionState: currentPresentation.interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: state.notificationPreviews,
            displayReason: currentPresentation.displayReason
        )
        return OverlayControllerState(
            panelState: OverlayPanelState(
                presentationState: presentation,
                placementPlan: overlayState.panelState.placementPlan
            ),
            menuSnapshot: overlayState.menuSnapshot,
            lastRoutedAction: overlayState.lastRoutedAction
        )
    }

    private func clearNotificationPeek(state: NotchViewModelState) -> NotchViewModelPlan {
        let presentation = presentationState(
            displayState: .closed,
            previews: state.sessionPreviews,
            focusedSessionId: state.focusedSessionId,
            interactionState: PanelInteractionState(displayState: .closed),
            usagePresentation: state.usagePresentation,
            notificationPreviews: [],
            displayReason: .none
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            overlayState: overlayPlan.nextState,
            notificationPreviews: []
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: [.clearNotificationPeek]
                + overlayPlan.actions.map(NotchViewModelAction.overlay)
                + [
                    .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
                ]
        )
    }

    private func applyOnboardingState(
        _ onboardingState: OnboardingState,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let interactionState = PanelInteractionState(
            displayState: .onboarding,
            onboardingActive: true
        )
        let presentation = presentationState(
            displayState: .onboarding,
            previews: state.sessionPreviews,
            focusedSessionId: state.focusedSessionId,
            interactionState: interactionState,
            usagePresentation: state.usagePresentation,
            notificationPreviews: state.notificationPreviews,
            displayReason: .onboarding
        )
        let overlayPlan = overlayController.plan(
            .replacePresentation(presentation),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            overlayState: overlayPlan.nextState,
            onboardingState: onboardingState
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: overlayPlan.actions.map(NotchViewModelAction.overlay) + [
                .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
            ]
        )
    }

    private func recordQuestionSelection(
        requestId: String,
        sessionId: String,
        selection: String,
        state: NotchViewModelState
    ) -> NotchViewModelPlan {
        let nextSelections = state.questionSelections.recording(
            requestId: requestId,
            selection: selection
        )
        let routePlan = overlayController.plan(
            .sessionGesture(.answerQuestion(requestId: requestId, sessionId: sessionId)),
            from: state.overlayState
        )

        let nextState = replacing(
            state,
            overlayState: routePlan.nextState,
            questionSelections: nextSelections
        )

        return NotchViewModelPlan(
            nextState: nextState,
            actions: [
                .storeQuestionSelection(requestId: requestId, selection: selection)
            ] + [
                .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: nextState))))
            ] + routePlan.actions.map(NotchViewModelAction.overlay)
        )
    }

    private func presentationState(
        displayState: PanelDisplayState,
        previews: [SessionCardPreview],
        focusedSessionId: String?,
        interactionState: PanelInteractionState,
        usagePresentation: UsagePresentationSnapshot?,
        notificationPreviews: [SessionCardPreview],
        displayReason: DisplayIntentReason,
        isPreviewingCompletionCard: Bool = false,
        completionPreviewSessionID: String? = nil,
        completionPreview: SessionCardPreview? = nil,
        completionPreviewSession: AgentSession? = nil
    ) -> NotchPresentationState {
        let base = presentationBuilder.presentationState(
            displayState: displayState,
            previews: previews,
            focusedSessionId: focusedSessionId,
            interactionState: interactionState,
            usageDisplayState: usagePresentation?.displayState,
            notificationPreviews: notificationPreviews,
            displayReason: displayReason,
            isPreviewingCompletionCard: isPreviewingCompletionCard,
            completionPreviewSessionID: completionPreviewSessionID,
            completionPreview: completionPreview,
            completionPreviewSession: completionPreviewSession
        )
        return base
    }

    private func completionOverviewSeen(
        after command: PanelInteractionCommand,
        previousState: NotchViewModelState,
        nextOverlayState: OverlayControllerState
    ) -> Bool {
        guard case .hoverRevealTick = command,
              previousState.overlayState.panelState.presentationState.displayState != .expanded,
              nextOverlayState.panelState.presentationState.displayState == .expanded
        else {
            return previousState.completionOverviewSeen
        }
        return true
    }

    private func quietSceneCompletionPending(
        after command: PanelInteractionCommand,
        previousState: NotchViewModelState,
        nextOverlayState: OverlayControllerState
    ) -> Bool {
        guard completionOverviewSeen(
            after: command,
            previousState: previousState,
            nextOverlayState: nextOverlayState
        ) else {
            return previousState.quietSceneCompletionPending
        }
        return false
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

    private func completionPreviewSession(
        for preview: SessionCardPreview,
        state: NotchViewModelState
    ) -> AgentSession {
        state.sessions.first { $0.id == preview.sessionId }
            ?? AgentSession(
                id: preview.sessionId,
                source: preview.sourceBadge,
                cwd: preview.localCwdDisplay,
                activeTool: preview.activeTool,
                activitySummary: preview.activitySummary,
                safeTitle: preview.displayTitle,
                originalStatus: .unknown,
                isRestored: preview.restored,
                isRemote: preview.isRemote,
                hasUnreadCompletion: preview.unreadCompletionMarker,
                redactionLevel: preview.redactionLevel
            )
    }

    private func replacing(
        _ state: NotchViewModelState,
        sessions: [AgentSession]? = nil,
        originalCompactRuntimeState: OriginalCompactRuntimeState? = nil,
        sessionPreviews: [SessionCardPreview]? = nil,
        actionRequestPreviews: [ActionRequestPreview]? = nil,
        focusedSessionId: String?? = nil,
        overlayState: OverlayControllerState? = nil,
        usagePresentation: UsagePresentationSnapshot? = nil,
        onboardingState: OnboardingState? = nil,
        onboardingDemoState: OnboardingDemoRunnerState? = nil,
        questionSelections: QuestionSelectionState? = nil,
        notificationPreviews: [SessionCardPreview]? = nil,
        localPreferences: NotchLocalUIPreferences? = nil,
        manuallyExpandedSessionIDs: Set<String>? = nil,
        autoExpandOnTaskComplete: Bool? = nil,
        completionOverviewSeen: Bool? = nil,
        quietSceneCompletionPending: Bool? = nil
    ) -> NotchViewModelState {
        NotchViewModelState(
            sessions: sessions ?? state.sessions,
            originalCompactRuntimeState: originalCompactRuntimeState ?? state.originalCompactRuntimeState,
            sessionPreviews: sessionPreviews ?? state.sessionPreviews,
            actionRequestPreviews: actionRequestPreviews ?? state.actionRequestPreviews,
            focusedSessionId: focusedSessionId ?? state.focusedSessionId,
            overlayState: overlayState ?? state.overlayState,
            usagePresentation: usagePresentation ?? state.usagePresentation,
            onboardingState: onboardingState ?? state.onboardingState,
            onboardingDemoState: onboardingDemoState ?? state.onboardingDemoState,
            questionSelections: questionSelections ?? state.questionSelections,
            notificationPreviews: notificationPreviews ?? state.notificationPreviews,
            localPreferences: localPreferences ?? state.localPreferences,
            manuallyExpandedSessionIDs: manuallyExpandedSessionIDs ?? state.manuallyExpandedSessionIDs,
            autoExpandOnTaskComplete: autoExpandOnTaskComplete ?? state.autoExpandOnTaskComplete,
            completionOverviewSeen: completionOverviewSeen ?? state.completionOverviewSeen,
            quietSceneCompletionPending: quietSceneCompletionPending ?? state.quietSceneCompletionPending
        )
    }
}
