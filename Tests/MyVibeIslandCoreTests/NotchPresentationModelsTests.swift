import XCTest
@testable import MyVibeIslandCore

final class NotchPresentationModelsTests: XCTestCase {
    func testQuietSceneMonitorStateSelectsFirstEnabledActiveDetectorInOriginalOrder() {
        let state = QuietSceneMonitorState(
            detectorEnabled: [
                .focus: false,
                .screenObscured: true,
                .screenCapture: true,
            ],
            detectorActive: [
                .focus: true,
                .screenObscured: true,
                .screenCapture: true,
            ]
        )

        XCTAssertEqual(state.activeDetector, .screenObscured)
        XCTAssertTrue(state.isQuietSceneActive)
        XCTAssertEqual(QuietSceneDetectorID.screenObscured.preferenceKey, "quietDetectorEnabled_screenObscured")
    }

    func testNotchPresentationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotchPresentationMatrixFixture.self,
            from: try FixtureLoader.data("runtime/notch-presentation-matrix")
        )
        let builder = NotchPresentationBuilder()
        let waiting = builder.pillSnapshot(
            previews: [
                preview(id: "active", status: .active),
                preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"]),
            ],
            usageDisplayState: availableUsageDisplayState()
        )
        let completed = builder.pillSnapshot(
            previews: [preview(id: "completed", status: .completed, hasUnreadCompletion: true)],
            usageDisplayState: availableUsageDisplayState()
        )
        let usageRing = builder.pillSnapshot(
            previews: [preview(id: "idle", status: .idle)],
            usageDisplayState: availableUsageDisplayState(percent: 42)
        )
        let activeCount = builder.pillSnapshot(
            previews: [
                preview(id: "one", status: .active),
                preview(id: "two", status: .active),
            ],
            usageDisplayState: nil
        )
        let focused = builder.presentationState(
            displayState: .expanded,
            previews: [preview(id: "session-1", status: .active)],
            focusedSessionId: "session-1",
            interactionState: PanelInteractionState(displayState: .expanded),
            displayReason: .keyboardShortcut
        )
        let droppedFocus = builder.presentationState(
            displayState: .expanded,
            previews: [preview(id: "session-1", status: .active)],
            focusedSessionId: "missing",
            interactionState: PanelInteractionState(displayState: .expanded),
            displayReason: .keyboardShortcut
        )
        let notificationPeek = builder.presentationState(
            displayState: .notificationPeek,
            previews: [],
            focusedSessionId: nil,
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            notificationPreviews: [
                preview(id: "notify", status: .completed, hasUnreadCompletion: true),
            ],
            displayReason: .notificationPeek
        )

        let actual = NotchPresentationMatrixFixture(rows: [
            NotchPresentationMatrixRow(id: "waiting-priority", pillSnapshot: waiting),
            NotchPresentationMatrixRow(id: "completed-unread", pillSnapshot: completed),
            NotchPresentationMatrixRow(id: "usage-ring-fallback", pillSnapshot: usageRing),
            NotchPresentationMatrixRow(id: "active-count", pillSnapshot: activeCount),
            NotchPresentationMatrixRow(id: "focused-session-preserved", presentationState: focused),
            NotchPresentationMatrixRow(id: "focused-session-dropped", presentationState: droppedFocus),
            NotchPresentationMatrixRow(id: "notification-peek", presentationState: notificationPeek),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testWaitingSessionTakesPillPriorityAndShowsWaitingSlot() {
        let previews = [
            preview(id: "active", status: .active),
            preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"])
        ]

        let snapshot = NotchPresentationBuilder().pillSnapshot(
            previews: previews,
            usageDisplayState: availableUsageDisplayState()
        )

        XCTAssertEqual(snapshot.primaryAgent, "codex")
        XCTAssertEqual(snapshot.activeCount, 1)
        XCTAssertEqual(snapshot.waitingCount, 1)
        XCTAssertEqual(snapshot.completedUnreadCount, 0)
        XCTAssertEqual(snapshot.visualState, .waiting)
        XCTAssertEqual(snapshot.rightSlotContent, .waitingAction(count: 1))
    }

    func testUnreadCompletionSlotWinsWhenNoWaitingActionExists() {
        let previews = [
            preview(id: "completed", status: .completed, hasUnreadCompletion: true)
        ]

        let snapshot = NotchPresentationBuilder().pillSnapshot(
            previews: previews,
            usageDisplayState: availableUsageDisplayState()
        )

        XCTAssertEqual(snapshot.visualState, .completed)
        XCTAssertEqual(snapshot.completedUnreadCount, 1)
        XCTAssertEqual(snapshot.rightSlotContent, .unreadCompletion(count: 1))
    }

    func testCompletionUnreadDotDerivesVisibilityFromPillSnapshot() {
        let dot = CompletionUnreadDot(snapshot: PillSnapshot(completedUnreadCount: 3))
        let hidden = CompletionUnreadDot(snapshot: PillSnapshot(completedUnreadCount: 0))

        XCTAssertTrue(dot.isVisible)
        XCTAssertEqual(dot.count, 3)
        XCTAssertEqual(dot.accessibilityLabel, "3 unread completions")
        XCTAssertFalse(hidden.isVisible)
    }

    func testCompletionUnreadDotKeepsUnreadCompletionVisibleWhenAutoExpansionIsNotQuiet() {
        let unread = PillSnapshot(completedUnreadCount: 2)

        XCTAssertTrue(CompletionUnreadDot(
            snapshot: unread,
            autoExpandOnTaskComplete: false,
            completionOverviewSeen: false
        ).isVisible)
        XCTAssertTrue(CompletionUnreadDot(
            snapshot: unread,
            autoExpandOnTaskComplete: true,
            completionOverviewSeen: false
        ).isVisible)
        XCTAssertFalse(CompletionUnreadDot(
            snapshot: unread,
            autoExpandOnTaskComplete: true,
            completionOverviewSeen: false,
            quietSceneCompletionPending: true
        ).isVisible)
        XCTAssertFalse(CompletionUnreadDot(
            snapshot: unread,
            autoExpandOnTaskComplete: false,
            completionOverviewSeen: true
        ).isVisible)
        XCTAssertFalse(CompletionUnreadDot(
            snapshot: PillSnapshot(completedUnreadCount: 0),
            autoExpandOnTaskComplete: false,
            completionOverviewSeen: false
        ).isVisible)
    }

    func testStateIndicatorSummarizesPillVisualState() {
        let indicator = StateIndicator(snapshot: PillSnapshot(
            waitingCount: 2,
            visualState: .waiting,
            rightSlotContent: .waitingAction(count: 2)
        ))

        XCTAssertEqual(indicator.kind, .waiting)
        XCTAssertEqual(indicator.count, 2)
        XCTAssertEqual(indicator.accessibilityLabel, "2 waiting actions")
    }

    func testUsageRingIsRightSlotFallbackWhenNoSessionAlertExists() {
        let usage = availableUsageDisplayState(percent: 42)

        let snapshot = NotchPresentationBuilder().pillSnapshot(
            previews: [preview(id: "idle", status: .idle)],
            usageDisplayState: usage
        )

        XCTAssertEqual(snapshot.visualState, .idle)
        XCTAssertEqual(snapshot.usageInfoBar, UsageInfoBar.make(displayState: usage))
        XCTAssertEqual(snapshot.rightSlotContent, .usageRing(UsageRingBadge.make(displayState: usage)))
    }

    func testActiveCountSlotIsUsedForMultipleActiveSessionsWithoutUsageRing() {
        let snapshot = NotchPresentationBuilder().pillSnapshot(
            previews: [
                preview(id: "one", status: .active),
                preview(id: "two", status: .active)
            ],
            usageDisplayState: nil
        )

        XCTAssertEqual(snapshot.visualState, .active)
        XCTAssertEqual(snapshot.activeCount, 2)
        XCTAssertEqual(snapshot.rightSlotContent, .activeCount(2))
    }

    func testPresentationStatePreservesFocusedSessionOnlyWhenPresent() {
        let builder = NotchPresentationBuilder()
        let previews = [preview(id: "session-1", status: .active)]

        let preserved = builder.presentationState(
            displayState: .expanded,
            previews: previews,
            focusedSessionId: "session-1",
            interactionState: PanelInteractionState(displayState: .expanded),
            displayReason: .keyboardShortcut
        )
        XCTAssertEqual(preserved.focusedSessionId, "session-1")

        let dropped = builder.presentationState(
            displayState: .expanded,
            previews: previews,
            focusedSessionId: "missing",
            interactionState: PanelInteractionState(displayState: .expanded),
            displayReason: .keyboardShortcut
        )
        XCTAssertNil(dropped.focusedSessionId)
    }

    func testNotificationPreviewsAreStoredWithoutChangingPillCounts() {
        let preview = preview(id: "notify", status: .completed, hasUnreadCompletion: true)

        let state = NotchPresentationBuilder().presentationState(
            displayState: .notificationPeek,
            previews: [],
            focusedSessionId: nil,
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            notificationPreviews: [preview],
            displayReason: .notificationPeek
        )

        XCTAssertEqual(state.displayState, .notificationPeek)
        XCTAssertEqual(state.notificationPreviews, [preview])
        XCTAssertEqual(state.pillSnapshot.activeCount, 0)
        XCTAssertEqual(state.pillSnapshot.completedUnreadCount, 0)
        XCTAssertEqual(state.displayReason, .notificationPeek)
    }

    func testPresentationStateRoundTripsThroughJSON() throws {
        let state = NotchPresentationBuilder().presentationState(
            displayState: .switcher,
            previews: [preview(id: "session-1", status: .failed)],
            focusedSessionId: "session-1",
            interactionState: PanelInteractionState(displayState: .switcher, isPinned: true),
            usageDisplayState: availableUsageDisplayState(),
            displayReason: .userHover
        )

        let decoded = try JSONDecoder().decode(
            NotchPresentationState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    func testLegacyPresentationStateDecodingDerivesMissingRootContentStatus() throws {
        let state = NotchPresentationState(displayState: .notificationPeek)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )
        object.removeValue(forKey: "rootContentStatus")

        let decoded = try JSONDecoder().decode(
            NotchPresentationState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.rootContentStatus, .compact)
    }

    private func preview(
        id: String,
        status: SessionStatus,
        pendingRequestIds: [String] = [],
        hasUnreadCompletion: Bool = false
    ) -> SessionCardPreview {
        SessionCardPreview(
            session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/tmp/project",
                safeTitle: "\(id) title",
                tasks: tasks(for: status),
                pendingRequestIds: pendingRequestIds,
                hasUnreadCompletion: hasUnreadCompletion
            ),
            snapshot: SessionSnapshot(
                sessionId: id,
                source: "codex",
                status: status,
                cwdDisplay: "project",
                activeTaskCount: status == .active ? 1 : 0,
                todoCount: 0,
                waitingActionSummary: WaitingActionSummary(
                    pendingRequestIds: pendingRequestIds,
                    needsAttention: !pendingRequestIds.isEmpty
                ),
                redactionLevel: .metadataOnly,
                isRestored: false
            )
        )
    }

    private func tasks(for status: SessionStatus) -> [TaskItem] {
        switch status {
        case .active:
            return [TaskItem(id: "task-active", subject: "Active", status: .active)]
        case .completed:
            return [TaskItem(id: "task-completed", subject: "Done", status: .completed)]
        case .failed:
            return [TaskItem(id: "task-failed", subject: "Failed", status: .failed)]
        case .waiting, .idle:
            return []
        }
    }

    private func availableUsageDisplayState(percent: Double = 68) -> UsageDisplayState {
        UsageDisplayState(
            status: .available,
            providerDisplayName: "Codex",
            displayStyle: .ringBadge,
            valueMode: .used,
            title: "Codex",
            primaryText: "\(Int(percent))% used",
            percent: percent
        )
    }
}

private struct NotchPresentationMatrixFixture: Codable, Equatable {
    let rows: [NotchPresentationMatrixRow]
}

private struct NotchPresentationMatrixRow: Codable, Equatable {
    let id: String
    let primaryAgent: String?
    let activeCount: Int
    let waitingCount: Int
    let completedUnreadCount: Int
    let visualState: PillVisualState
    let rightSlotSummary: String
    let usageTitle: String?
    let usagePrimaryText: String?
    let completionDotVisible: Bool
    let completionDotLabel: String
    let stateIndicatorKind: StateIndicatorKind
    let stateIndicatorLabel: String
    let presentationDisplayState: PanelDisplayState?
    let focusedSessionId: String?
    let displayReason: DisplayIntentReason?
    let sessionPreviewIds: [String]
    let notificationPreviewIds: [String]

    init(
        id: String,
        pillSnapshot: PillSnapshot
    ) {
        self.id = id
        primaryAgent = pillSnapshot.primaryAgent
        activeCount = pillSnapshot.activeCount
        waitingCount = pillSnapshot.waitingCount
        completedUnreadCount = pillSnapshot.completedUnreadCount
        visualState = pillSnapshot.visualState
        rightSlotSummary = Self.describe(pillSnapshot.rightSlotContent)
        usageTitle = pillSnapshot.usageInfoBar?.title
        usagePrimaryText = pillSnapshot.usageInfoBar?.primaryText
        let dot = CompletionUnreadDot(snapshot: pillSnapshot)
        completionDotVisible = dot.isVisible
        completionDotLabel = dot.accessibilityLabel
        let indicator = StateIndicator(snapshot: pillSnapshot)
        stateIndicatorKind = indicator.kind
        stateIndicatorLabel = indicator.accessibilityLabel
        presentationDisplayState = nil
        focusedSessionId = nil
        displayReason = nil
        sessionPreviewIds = []
        notificationPreviewIds = []
    }

    init(
        id: String,
        presentationState: NotchPresentationState
    ) {
        self.id = id
        let pillSnapshot = presentationState.pillSnapshot
        primaryAgent = pillSnapshot.primaryAgent
        activeCount = pillSnapshot.activeCount
        waitingCount = pillSnapshot.waitingCount
        completedUnreadCount = pillSnapshot.completedUnreadCount
        visualState = pillSnapshot.visualState
        rightSlotSummary = Self.describe(pillSnapshot.rightSlotContent)
        usageTitle = pillSnapshot.usageInfoBar?.title
        usagePrimaryText = pillSnapshot.usageInfoBar?.primaryText
        let dot = CompletionUnreadDot(snapshot: pillSnapshot)
        completionDotVisible = dot.isVisible
        completionDotLabel = dot.accessibilityLabel
        let indicator = StateIndicator(snapshot: pillSnapshot)
        stateIndicatorKind = indicator.kind
        stateIndicatorLabel = indicator.accessibilityLabel
        presentationDisplayState = presentationState.displayState
        focusedSessionId = presentationState.focusedSessionId
        displayReason = presentationState.displayReason
        sessionPreviewIds = presentationState.sessionPreviews.map(\.sessionId)
        notificationPreviewIds = presentationState.notificationPreviews.map(\.sessionId)
    }

    private static func describe(_ content: PillRightSlotContent) -> String {
        switch content {
        case .none:
            return "none"
        case let .usageRing(badge):
            return "usageRing:\(badge.title):\(badge.percent.map { String(Int($0)) } ?? "nil")"
        case let .unreadCompletion(count):
            return "unreadCompletion:\(count)"
        case let .waitingAction(count):
            return "waitingAction:\(count)"
        case let .activeCount(count):
            return "activeCount:\(count)"
        }
    }
}
