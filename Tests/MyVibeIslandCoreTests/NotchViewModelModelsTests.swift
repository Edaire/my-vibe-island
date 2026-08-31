import XCTest
@testable import MyVibeIslandCore

final class NotchViewModelModelsTests: XCTestCase {
    func testRuntimeSnapshotPublicationUsesOneReducerCommand() {
        let reducer = NotchViewModelReducer()
        let session = AgentSession(
            id: "runtime-publication",
            source: "codex",
            cwd: "/tmp/runtime-publication"
        )
        let preview = SessionCardPreview(session: session)
        let snapshot = IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [preview]
        )

        let plan = reducer.reduce(
            .replaceRuntimeSnapshot(snapshot),
            state: NotchViewModelState()
        )

        XCTAssertEqual(plan.nextState.sessions, [session])
        XCTAssertEqual(plan.nextState.sessionPreviews, [preview])
        XCTAssertTrue(plan.nextState.actionRequestPreviews.isEmpty)
        XCTAssertEqual(
            plan.actions.filter {
                if case .overlay(.renderIslandSurface) = $0 { return true }
                return false
            }.count,
            1
        )
    }

    func testAcceptedHoverCompletionOverviewConsumesQuietSceneCompletionPending() {
        let controller = PanelInteractionController(
            settings: BehaviourSettings(hoverExpandDelay: 0)
        )
        let reducer = NotchViewModelReducer(
            overlayController: OverlayControllerModel(
                panelController: OverlayPanelControllerModel(interactionController: controller)
            )
        )
        let initialState = NotchViewModelState(
            sessionPreviews: [SessionCardPreview(session: AgentSession(
                id: "completed",
                source: "codex",
                cwd: "/tmp/project",
                originalStatus: .ended,
                hasUnreadCompletion: true
            ))],
            autoExpandOnTaskComplete: true,
            quietSceneCompletionPending: true
        )

        let entered = reducer.reduce(
            .panelInteraction(.setMenuBarHover(true)),
            state: initialState
        )
        let revealed = reducer.reduce(
            .panelInteraction(.hoverRevealTick(generation: 1)),
            state: entered.nextState
        )

        XCTAssertTrue(revealed.nextState.completionOverviewSeen)
        XCTAssertFalse(revealed.nextState.quietSceneCompletionPending)
    }

    func testTaskCompletionDecisionSuppressesAutoExpansionInQuietScene() {
        let reducer = NotchViewModelReducer()
        let preview = self.preview(id: "quiet-completed", status: .completed, hasUnreadCompletion: true)

        let plan = reducer.reduce(
            .consumeTaskCompletion(
                sessionId: "quiet-completed",
                autoExpandOnTaskComplete: true,
                quietSceneActive: true
            ),
            state: NotchViewModelState(sessionPreviews: [preview])
        )

        XCTAssertTrue(plan.nextState.quietSceneCompletionPending)
        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.displayState,
            .closed
        )
        XCTAssertEqual(plan.nextState.originalCompactRuntimeState.completionFlashTick, 0)
    }

    func testCompletionOverviewResetsForNewUnreadCompletionAndIsSeenAfterAcceptedHoverPromotion() {
        let reducer = NotchViewModelReducer(
            overlayController: OverlayControllerModel(
                panelController: OverlayPanelControllerModel(
                    interactionController: PanelInteractionController(
                        settings: BehaviourSettings(autoExpandOnTaskComplete: false)
                    )
                )
            )
        )
        let unread = preview(id: "done", status: .completed, hasUnreadCompletion: true)
        let initial = NotchViewModelState(
            sessionPreviews: [],
            autoExpandOnTaskComplete: false,
            completionOverviewSeen: true
        )

        let completion = reducer.reduce(.replaceSessionPreviews([unread]), state: initial)

        XCTAssertFalse(completion.nextState.completionOverviewSeen)
        XCTAssertTrue(IslandSurfaceSections(surface: IslandSurfaceSnapshot(state: completion.nextState))
            .isCompletionUnreadOverviewVisible)

        let enteredHover = reducer.reduce(
            .panelInteraction(.setMenuBarHover(true)),
            state: completion.nextState
        )
        XCTAssertFalse(enteredHover.nextState.completionOverviewSeen)

        let promoted = reducer.reduce(
            .panelInteraction(.hoverRevealTick(generation: 1)),
            state: enteredHover.nextState
        )

        XCTAssertTrue(promoted.nextState.completionOverviewSeen)
        XCTAssertFalse(IslandSurfaceSections(surface: IslandSurfaceSnapshot(state: promoted.nextState))
            .isCompletionUnreadOverviewVisible)
    }

    func testManualSessionExpansionIsModelOwnedAndRerendersTheExpandedList() {
        let sessions = (0..<4).map { index in
            AgentSession(
                id: "session-\(index)",
                source: "codex",
                cwd: "/work/session-\(index)",
                originalStatus: .waitingForInput,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        }
        let state = NotchViewModelState(
            sessions: sessions,
            sessionPreviews: sessions.map { SessionCardPreview(session: $0) }
        )

        let plan = NotchViewModelReducer().reduce(
            .toggleManualSessionExpansion(sessionID: sessions[2].id),
            state: state
        )

        XCTAssertEqual(plan.nextState.manuallyExpandedSessionIDs, [sessions[2].id])
        XCTAssertTrue(plan.actions.contains(.overlay(.renderIslandSurface(
            IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))
        ))))

        let secondPlan = NotchViewModelReducer().reduce(
            .toggleManualSessionExpansion(sessionID: sessions[2].id),
            state: plan.nextState
        )

        XCTAssertTrue(secondPlan.nextState.manuallyExpandedSessionIDs.isEmpty)
    }
    func testNotchLocalUIPreferencesDefaultToCompactMode() {
        XCTAssertTrue(NotchLocalUIPreferences().compactMode)
    }

    func testNotchViewModelReducerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotchViewModelReducerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/notch-view-model-reducer-matrix")
        )
        let reducer = NotchViewModelReducer()

        let actual = NotchViewModelReducerMatrixFixture(rows: [
            NotchViewModelReducerMatrixRow(
                id: "replace-session-previews",
                plan: reducer.reduce(
                    .replaceSessionPreviews([
                        preview(id: "session-1", status: .active),
                        preview(id: "session-2", status: .waiting, pendingRequestIds: ["request-1"]),
                    ]),
                    state: NotchViewModelState(focusedSessionId: "session-1")
                )
            ),
            NotchViewModelReducerMatrixRow(
                id: "apply-usage-presentation",
                plan: reducer.reduce(
                    .applyUsagePresentation(usagePresentation(percent: 73)),
                    state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .idle)])
                )
            ),
            NotchViewModelReducerMatrixRow(
                id: "show-notification-peek",
                plan: reducer.reduce(
                    .showNotificationPeek([
                        preview(id: "done", status: .completed, hasUnreadCompletion: true),
                    ]),
                    state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])
                )
            ),
            NotchViewModelReducerMatrixRow(
                id: "apply-onboarding-state",
                plan: reducer.reduce(
                    .applyOnboardingState(OnboardingState(currentStep: .demo)),
                    state: NotchViewModelState()
                )
            ),
            NotchViewModelReducerMatrixRow(
                id: "record-question-selection",
                plan: reducer.reduce(
                    .recordQuestionSelection(requestId: "request-1", sessionId: "session-1", selection: "approve"),
                    state: NotchViewModelState()
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testReplacingSessionPreviewsRebuildsPresentationAndPreservesExistingFocus() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(focusedSessionId: "session-1")
        let previews = [
            preview(id: "session-1", status: .active),
            preview(id: "session-2", status: .waiting, pendingRequestIds: ["request-1"])
        ]

        let plan = reducer.reduce(.replaceSessionPreviews(previews), state: state)

        XCTAssertEqual(plan.nextState.sessionPreviews, previews)
        XCTAssertEqual(plan.nextState.focusedSessionId, "session-1")
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.focusedSessionId, "session-1")
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.pillSnapshot.waitingCount, 1)
        XCTAssertEqual(plan.actions, [
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))))
        ])
    }

    func testReplacingSessionPreviewsClearsStaleNotificationPreviewsWhenCompletionIsNoLongerUnread() {
        let reducer = NotchViewModelReducer()
        let unread = preview(id: "done", status: .completed, hasUnreadCompletion: true)
        let active = preview(id: "done", status: .active)
        let state = NotchViewModelState(
            sessionPreviews: [unread],
            notificationPreviews: [unread]
        )

        let plan = reducer.reduce(.replaceSessionPreviews([active]), state: state)

        XCTAssertTrue(plan.nextState.notificationPreviews.isEmpty)
        XCTAssertTrue(plan.nextState.overlayState.panelState.presentationState.notificationPreviews.isEmpty)
    }

    func testReplacingSessionPreviewsPreservesStoredFocusWhenPreviewIsMissing() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(focusedSessionId: "missing")

        let plan = reducer.reduce(.replaceSessionPreviews([preview(id: "session-1", status: .active)]), state: state)

        XCTAssertEqual(plan.nextState.focusedSessionId, "missing")
        XCTAssertNil(plan.nextState.overlayState.panelState.presentationState.focusedSessionId)
    }

    func testReplacingSessionsStoresFullSessionsAndFiltersRenderItemsInSourceOrder() throws {
        let previews = [
            preview(id: "session-a", status: .active),
            preview(id: "session-b", status: .waiting),
        ]
        let sessions = [
            fullSession(id: "session-b", command: "swift test B"),
            fullSession(id: "unmatched", command: "swift test unmatched"),
            fullSession(id: "session-a", command: "swift test A"),
        ]
        let reducer = NotchViewModelReducer()
        let state = reducer.reduce(
            .replaceSessionPreviews(previews),
            state: NotchViewModelState()
        ).nextState

        let plan = reducer.reduce(.replaceSessions(sessions), state: state)
        let renderList = try XCTUnwrap(plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)
        let compactItem = try XCTUnwrap(renderList.items.first { $0.section == .compactPill })

        XCTAssertEqual(plan.nextState.sessions, sessions)
        XCTAssertEqual(plan.nextState.sessionPreviews, previews)
        XCTAssertEqual(IslandSurfaceSnapshot(state: plan.nextState).sessions, sessions)
        XCTAssertEqual(compactItem.sessionIds, ["session-a", "session-b"])
        XCTAssertEqual(compactItem.sessions, [sessions[0], sessions[2]])
    }

    func testCompactPillKeepsFullSessionCountWhenPrimaryIdsAreCapped() throws {
        let sessions = (0..<12).map { index in
            fullSession(id: "session-\(index)", command: "work \(index)")
        }
        let previews = sessions.prefix(10).map {
            preview(id: $0.id, status: .active)
        }
        let sections = IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .sessionCards],
            onboardingStep: nil,
            primarySessionIds: previews.map(\.sessionId)
        )

        let renderList = IslandSurfaceRenderList(sections: sections)
        let compactItem = try XCTUnwrap(renderList.items.first { $0.section == .compactPill })
        let sessionCardsItem = try XCTUnwrap(renderList.items.first { $0.section == .sessionCards })

        XCTAssertEqual(compactItem.sessionIds.count, 10)
        XCTAssertEqual(compactItem.sessions.count, 12)
        XCTAssertEqual(sessionCardsItem.sessions.count, 12)
        XCTAssertEqual(sessionCardsItem.sessionIds, sessions.map(\.id))
    }

    func testReplacingSessionsPreservesExistingFocus() {
        let state = NotchViewModelState(focusedSessionId: "session-1")

        let plan = NotchViewModelReducer().reduce(
            .replaceSessions([fullSession(id: "session-1", command: "swift test")]),
            state: state
        )

        XCTAssertEqual(plan.nextState.focusedSessionId, "session-1")
    }

    func testIslandSurfaceSectionsCarrySessionsIntoRenderItemsInSourceOrder() throws {
        let sessions = [
            fullSession(id: "session-b", command: "swift test B"),
            fullSession(id: "unmatched", command: "swift test unmatched"),
            fullSession(id: "session-a", command: "swift test A"),
        ]
        let surface = IslandSurfaceSnapshot(
            sessions: sessions,
            displayStatus: .closed,
            layoutMode: .compact,
            focusedSessionId: nil,
            presentationState: NotchPresentationState(
                displayState: .closed,
                sessionPreviews: [
                    preview(id: "session-a", status: .active),
                    preview(id: "session-b", status: .waiting),
                ]
            ),
            sessionSets: NotchSessionSets(visibleSessionIds: ["session-a", "session-b"]),
            contentDimensions: NotchContentDimensions(),
            pillSnapshot: PillSnapshot(),
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(kind: .active)
        )

        let sections = IslandSurfaceSections(surface: surface)
        let compactItem = try XCTUnwrap(
            IslandSurfaceRenderList(sections: sections).items.first { $0.section == .compactPill }
        )

        XCTAssertEqual(sections.sessions, sessions)
        XCTAssertEqual(compactItem.sessions, [sessions[0], sessions[2]])
    }

    func testReplacingActionRequestsPreservesStatusWithoutRenderingApprovalControls() throws {
        let terminalQuestion = actionPreview(
            requestId: "question-1",
            kind: .question,
            prompt: "Choose a deployment target"
        )

        let plan = NotchViewModelReducer().reduce(
            .replaceActionRequestPreviews([terminalQuestion]),
            state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .waiting)])
        )
        let renderList = try XCTUnwrap(plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)

        XCTAssertEqual(plan.nextState.actionRequestPreviews, [terminalQuestion])
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayState, .closed)
        XCTAssertFalse(
            plan.nextState.overlayState.panelState.presentationState.interactionState.blockingActionVisible
        )
        XCTAssertTrue(renderList.sections.visibleSections.contains(.actionRequests))
        XCTAssertEqual(
            renderList.items.first { $0.section == .actionRequests }?.actionRequestPreviews,
            [terminalQuestion]
        )
        XCTAssertFalse(terminalQuestion.canResolveLocally)
    }

    func testReplacingActionRequestsPreservesPendingMouseLeaveCollapse() {
        let interaction = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: false,
            mouseLeaveCollapseGeneration: 9,
            expandedSince: 10
        )
        let presentation = NotchPresentationState(
            displayState: .expanded,
            interactionState: interaction
        )
        let state = NotchViewModelState(
            sessionPreviews: [preview(id: "session-1", status: .active)],
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(presentationState: presentation)
            )
        )

        let plan = NotchViewModelReducer().reduce(
            .replaceActionRequestPreviews([]),
            state: state
        )

        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.interactionState
                .mouseLeaveCollapseGeneration,
            9
        )

        let collapsePlan = NotchViewModelReducer().reduce(
            .panelInteraction(.mouseLeaveCollapseTick(generation: 9)),
            state: plan.nextState
        )
        XCTAssertEqual(
            collapsePlan.nextState.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    func testRemovingLastLocallyResolvablePermissionSchedulesMouseLeaveCollapseWhenPointerIsOutside() {
        let permission = actionPreview(
            requestId: "permission-1",
            sessionId: "approval-session",
            kind: .permission,
            prompt: "Allow /usr/bin/whoami?"
        )
        let reducer = NotchViewModelReducer()
        let initial = NotchViewModelState(sessionPreviews: [
            preview(id: "approval-session", status: .waiting)
        ])

        let blocking = reducer.reduce(
            .replaceActionRequestPreviews([permission]),
            state: initial
        )
        let resolved = reducer.reduce(
            .replaceActionRequestPreviews([]),
            state: blocking.nextState
        )

        let interaction = resolved.nextState.overlayState.panelState.presentationState.interactionState
        XCTAssertFalse(interaction.blockingActionVisible)
        XCTAssertFalse(interaction.isMouseInExpandedPanel)
        XCTAssertEqual(interaction.mouseLeaveCollapseGeneration, 1)
        XCTAssertTrue(resolved.actions.contains { action in
            guard case let .overlay(.applyPanelPlan(actions)) = action else {
                return false
            }
            return actions.contains(
                .forwardInteractionAction(.scheduleMouseLeaveCollapse(delay: 0.25, generation: 1))
            )
        })

        let collapsed = reducer.reduce(
            .panelInteraction(.mouseLeaveCollapseTick(generation: 1)),
            state: resolved.nextState
        )
        XCTAssertEqual(
            collapsed.nextState.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    func testReplacingLocallyResolvablePermissionImmediatelyExpandsAndBlocksPresentation() {
        let permission = actionPreview(
            requestId: "permission-1",
            sessionId: "approval-session",
            kind: .permission,
            prompt: "Allow /usr/bin/whoami?"
        )
        let state = NotchViewModelState(sessionPreviews: [
            preview(id: "ordinary-session", status: .active),
            preview(id: "approval-session", status: .waiting)
        ])

        let plan = NotchViewModelReducer().reduce(
            .replaceActionRequestPreviews([permission]),
            state: state
        )
        let presentation = plan.nextState.overlayState.panelState.presentationState

        XCTAssertTrue(permission.canResolveLocally)
        XCTAssertEqual(presentation.displayState, .expanded)
        XCTAssertEqual(presentation.displayReason, .blockingAction)
        XCTAssertTrue(presentation.interactionState.blockingActionVisible)
        XCTAssertEqual(presentation.focusedSessionId, "approval-session")
    }

    func testReplacingActionRequestsPromotesTheirSessionToTheFirstExpandedCard() throws {
        let permission = actionPreview(
            requestId: "permission-1",
            sessionId: "approval-session",
            kind: .permission,
            prompt: "Allow /usr/bin/whoami?"
        )
        let state = NotchViewModelState(sessionPreviews: [
            preview(id: "ordinary-session", status: .active),
            preview(id: "approval-session", status: .waiting)
        ])

        let plan = NotchViewModelReducer().reduce(
            .replaceActionRequestPreviews([permission]),
            state: state
        )
        let renderList = try XCTUnwrap(plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)

        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.sessionPreviews.map(\.sessionId),
            ["approval-session", "ordinary-session"]
        )
        XCTAssertEqual(
            plan.nextState.focusedSessionId,
            "approval-session"
        )
        XCTAssertEqual(
            renderList.items.first(where: { $0.section == .compactPill })?.sessionIds,
            ["approval-session", "ordinary-session"]
        )
    }

    func testFocusingSessionRoutesSelectionAndUpdatesPresentation() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])

        let plan = reducer.reduce(.focusSession("session-1"), state: state)

        XCTAssertEqual(plan.nextState.focusedSessionId, "session-1")
        XCTAssertEqual(plan.nextState.overlayState.lastRoutedAction, .selectSession(sessionId: "session-1"))
        XCTAssertEqual(plan.actions, [
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState)))),
            .overlay(.routeAction(.selectSession(sessionId: "session-1")))
        ])
    }

    func testClearFocusStillClearsPersistedFocus() {
        let reducer = NotchViewModelReducer()
        let focused = reducer.reduce(
            .focusSession("session-1"),
            state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])
        ).nextState

        let plan = reducer.reduce(.clearFocus, state: focused)

        XCTAssertNil(plan.nextState.focusedSessionId)
        XCTAssertNil(plan.nextState.overlayState.panelState.presentationState.focusedSessionId)
    }

    func testUsagePresentationUpdatesPillAndRequestsUsageRefresh() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .idle)])
        let usage = usagePresentation(percent: 73)

        let plan = reducer.reduce(.applyUsagePresentation(usage), state: state)

        XCTAssertEqual(plan.nextState.usagePresentation, usage)
        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.pillSnapshot.usageInfoBar,
            UsageInfoBar.make(displayState: usage.displayState)
        )
        XCTAssertEqual(plan.actions, [
            .refreshUsageDisplay,
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))))
        ])
    }

    func testNotificationPeekStoresNotificationPreviewsWithoutChangingSessionCounts() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])
        let notification = preview(id: "done", status: .completed, hasUnreadCompletion: true)

        let plan = reducer.reduce(.showNotificationPeek([notification]), state: state)

        XCTAssertEqual(plan.nextState.notificationPreviews, [notification])
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayState, .notificationPeek)
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.notificationPreviews, [notification])
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.pillSnapshot.activeCount, 1)
        XCTAssertEqual(plan.actions, [
            .showNotificationPeek([notification]),
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))))
        ])
    }

    func testCompletionRenderKeepsExpandedSessionListAndCarriesOnePreviewAddition() throws {
        let reducer = NotchViewModelReducer()
        let allPreviews = [
            preview(id: "active-1", status: .active),
            preview(id: "completed", status: .completed, hasUnreadCompletion: true),
            preview(id: "active-2", status: .active)
        ]
        let plan = reducer.reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: allPreviews)
        )
        let renderList = try XCTUnwrap(plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)

        XCTAssertEqual(plan.nextState.sessionPreviews, allPreviews)
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayState, .expanded)
        // V3 `sub_10010AEE4` classifies the automatic expanded route as a
        // task-completion producer, never as the compact notification surface.
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayReason, .taskComplete)
        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.sessionPreviews.map(\.sessionId),
            ["active-1", "completed", "active-2"]
        )
        XCTAssertEqual(
            renderList.items.first { $0.section == .sessionCards }?.sessionIds,
            ["active-1", "completed", "active-2"]
        )
        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.notificationPreviews.map(\.sessionId),
            ["completed"]
        )
        XCTAssertTrue(
            plan.nextState.overlayState.panelState.presentationState.isPreviewingCompletionCard
        )
        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.completionPreviewSessionID,
            "completed"
        )
    }

    func testCompletionPreviewFlagIsIndependentFromDisplayReason() {
        let presentation = NotchPresentationState(
            displayState: .expanded,
            notificationPreviews: [preview(id: "completed", status: .completed, hasUnreadCompletion: true)],
            displayReason: .userHover,
            isPreviewingCompletionCard: true
        )

        XCTAssertTrue(presentation.isPreviewingCompletionCard)
        XCTAssertEqual(presentation.displayReason, .userHover)
    }

    func testCompletionRenderCancelsPendingMouseLeaveCollapse() {
        let interaction = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: false,
            mouseLeaveCollapseGeneration: 4,
            expandedSince: 10
        )
        let state = NotchViewModelState(
            sessionPreviews: [preview(id: "completed", status: .completed, hasUnreadCompletion: true)],
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(
                    presentationState: NotchPresentationState(
                        displayState: .expanded,
                        interactionState: interaction
                    )
                )
            )
        )

        let plan = NotchViewModelReducer().reduce(
            .showCompletionRender(sessionId: "completed"),
            state: state
        )

        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.interactionState
                .mouseLeaveCollapseGeneration,
            nil
        )
        XCTAssertTrue(plan.actions.contains { action in
            guard case let .overlay(.applyPanelPlan(actions)) = action else {
                return false
            }
            return actions.contains(.forwardInteractionAction(.cancelMouseLeaveCollapse))
        })
    }

    func testSessionRefreshKeepsCompletionPreviewUntilItsLifecycleClearsIt() {
        let reducer = NotchViewModelReducer()
        let completed = preview(id: "completed", status: .completed, hasUnreadCompletion: true)
        let completionState = reducer.reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: [completed])
        ).nextState

        let refreshed = reducer.reduce(
            .replaceSessionPreviews([completed]),
            state: completionState
        )

        XCTAssertTrue(
            refreshed.nextState.overlayState.panelState.presentationState.isPreviewingCompletionCard
        )
        XCTAssertEqual(
            refreshed.nextState.overlayState.panelState.presentationState.completionPreviewSessionID,
            "completed"
        )
    }

    func testSessionRefreshRetainsCapturedCompletionContentWhenTheSameIDChanges() {
        let reducer = NotchViewModelReducer()
        let capturedSession = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/completed",
            safeTitle: "Completion captured at transition",
            originalStatus: .ended,
            lastAssistantMessage: "Original assistant response",
            firstUserMessage: "Original user request"
        )
        let captured = preview(
            id: "completed",
            status: .completed,
            hasUnreadCompletion: true,
            title: "Completion captured at transition"
        )
        let completionState = reducer.reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(
                sessions: [capturedSession],
                sessionPreviews: [captured]
            )
        ).nextState
        let refreshed = preview(
            id: "completed",
            status: .idle,
            title: "Live session after refresh"
        )

        let refreshedSession = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/completed",
            safeTitle: "Live session after refresh",
            originalStatus: .processing,
            lastAssistantMessage: "Live assistant output after refresh"
        )
        let refreshedState = reducer.reduce(
            .replaceSessions([refreshedSession]),
            state: completionState
        ).nextState
        let plan = reducer.reduce(.replaceSessionPreviews([refreshed]), state: refreshedState)
        let presentation = plan.nextState.overlayState.panelState.presentationState

        XCTAssertEqual(presentation.sessionPreviews, [refreshed])
        XCTAssertEqual(presentation.completionPreview, captured)
        XCTAssertEqual(presentation.completionPreview?.displayTitle, "Completion captured at transition")
        XCTAssertEqual(presentation.completionPreviewSession, capturedSession)
        XCTAssertEqual(presentation.completionPreviewSession?.lastAssistantMessage, "Original assistant response")
    }

    func testCompletionRenderSchedulesTheStandardFiveSecondAutoCollapse() {
        let plan = NotchViewModelReducer().reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: [
                preview(id: "completed", status: .completed, hasUnreadCompletion: true)
            ])
        )

        XCTAssertTrue(plan.actions.contains { action in
            guard case let .overlay(.applyPanelPlan(actions)) = action else {
                return false
            }
            return actions.contains(
                .forwardInteractionAction(.scheduleAutoCollapse(delay: 5, generation: 1))
            )
        })
    }

    func testCompletionRenderCarriesTaskCompleteProducerKindIntoFocusedSnapshot() {
        let plan = NotchViewModelReducer().reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: [
                preview(id: "completed", status: .completed, hasUnreadCompletion: true)
            ])
        )

        let snapshot = DisplayIntentFocusedSnapshot(state: plan.nextState)

        XCTAssertEqual(snapshot.displayStatus, .expanded)
        XCTAssertEqual(snapshot.transientRevealKind, .taskComplete)
    }

    func testHoverExpansionUsesTheFullSessionListAfterCompletionRenderCloses() throws {
        let reducer = NotchViewModelReducer()
        let allPreviews = [
            preview(id: "active-1", status: .active),
            preview(id: "completed", status: .completed, hasUnreadCompletion: true),
            preview(id: "active-2", status: .active)
        ]
        let completionState = reducer.reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: allPreviews)
        ).nextState
        let closedState = reducer.reduce(.toggleExpanded, state: completionState).nextState
        let hoverScheduledState = reducer.reduce(
            .panelInteraction(.setMenuBarHover(true)),
            state: closedState
        ).nextState
        let hoverPlan = reducer.reduce(
            .panelInteraction(.hoverRevealTick(generation: hoverScheduledState
                .overlayState.panelState.presentationState.interactionState.autoCollapseGeneration)),
            state: hoverScheduledState
        )
        let renderList = try XCTUnwrap(hoverPlan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)

        XCTAssertEqual(hoverPlan.nextState.overlayState.panelState.presentationState.displayState, .expanded)
        XCTAssertEqual(
            renderList.items.first { $0.section == .sessionCards }?.sessionIds,
            ["active-1", "completed", "active-2"]
        )
    }

    func testHoveringAnOpenCompletionRenderReplacesItsSingleCardWithTheFullSessionList() throws {
        let reducer = NotchViewModelReducer()
        let allPreviews = [
            preview(id: "active-1", status: .active),
            preview(id: "completed", status: .completed, hasUnreadCompletion: true),
            preview(id: "active-2", status: .active)
        ]
        let completionState = reducer.reduce(
            .showCompletionRender(sessionId: "completed"),
            state: NotchViewModelState(sessionPreviews: allPreviews)
        ).nextState
        let hoverPlan = reducer.reduce(
            .panelInteraction(.setExpandedPanelHover(true)),
            state: completionState
        )
        let renderList = try XCTUnwrap(hoverPlan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)

        XCTAssertEqual(hoverPlan.nextState.overlayState.panelState.presentationState.displayReason, .userHover)
        XCTAssertFalse(
            hoverPlan.nextState.overlayState.panelState.presentationState.isPreviewingCompletionCard
        )
        XCTAssertEqual(
            renderList.items.first { $0.section == .sessionCards }?.sessionIds,
            ["active-1", "completed", "active-2"]
        )
    }

    func testClearNotificationPeekClearsSurfaceRenderState() {
        let reducer = NotchViewModelReducer()
        let notification = preview(id: "done", status: .completed, hasUnreadCompletion: true)
        let peekPlan = reducer.reduce(
            .showNotificationPeek([notification]),
            state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])
        )

        let plan = reducer.reduce(.clearNotificationPeek, state: peekPlan.nextState)

        XCTAssertEqual(plan.nextState.notificationPreviews, [])
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayState, .closed)
        XCTAssertEqual(plan.actions, [
            .clearNotificationPeek,
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))))
        ])
    }

    func testOnboardingStateMarksInteractionAsOnboardingActive() {
        let reducer = NotchViewModelReducer()
        let onboarding = OnboardingState(currentStep: .demo)

        let plan = reducer.reduce(.applyOnboardingState(onboarding), state: NotchViewModelState())

        XCTAssertEqual(plan.nextState.onboardingState, onboarding)
        XCTAssertEqual(plan.nextState.overlayState.panelState.presentationState.displayState, .onboarding)
        XCTAssertTrue(plan.nextState.overlayState.panelState.presentationState.interactionState.onboardingActive)
        XCTAssertEqual(plan.actions, [
            .overlay(.renderPresentation(plan.nextState.overlayState.panelState.presentationState)),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState))))
        ])
    }

    func testQuestionSelectionUpdatesLocalStateAndRoutesAnswer() {
        let reducer = NotchViewModelReducer()

        let plan = reducer.reduce(
            .recordQuestionSelection(requestId: "request-1", sessionId: "session-1", selection: "approve"),
            state: NotchViewModelState()
        )

        XCTAssertEqual(plan.nextState.questionSelections.selections, ["request-1": "approve"])
        XCTAssertEqual(plan.nextState.overlayState.lastRoutedAction, .answerQuestion(requestId: "request-1", sessionId: "session-1"))
        XCTAssertEqual(plan.actions, [
            .storeQuestionSelection(requestId: "request-1", selection: "approve"),
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(surface: IslandSurfaceSnapshot(state: plan.nextState)))),
            .overlay(.routeAction(.answerQuestion(requestId: "request-1", sessionId: "session-1")))
        ])
    }

    func testToggleExpandedUpdatesPresentationAndRendersExpandedSurface() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 624, y: 914, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 416, y: 530, width: 680, height: 420),
            anchor: DisplayPoint(x: 756, y: 950),
            safeAreaAdjustment: 32
        )
        let reducer = NotchViewModelReducer()
        let synchronized = reducer.reduce(
            .synchronizePlacement(placement),
            state: NotchViewModelState(sessionPreviews: [preview(id: "session-1", status: .active)])
        ).nextState

        let plan = reducer.reduce(.toggleExpanded, state: synchronized)

        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.displayState,
            .expanded
        )
        XCTAssertTrue(plan.actions.contains {
            if case let .overlay(.applyPanelPlan(actions)) = $0 {
                return actions.contains(.applyFrame(placement.expandedFrame))
            }
            return false
        })
        XCTAssertTrue(plan.actions.contains {
            if case let .overlay(.renderIslandSurface(renderList)) = $0 {
                return renderList.sections.visibleSections.contains(.expandedPanel)
            }
            return false
        })
    }

    func testHoverSchedulingDoesNotRenderAnIntermediateOpeningSurface() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 416, y: 402, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 416, y: 402, width: 680, height: 580),
            anchor: DisplayPoint(x: 756, y: 982),
            safeAreaAdjustment: 32
        )
        let reducer = NotchViewModelReducer()
        let synchronized = reducer.reduce(
            .synchronizePlacement(placement),
            state: NotchViewModelState()
        ).nextState

        let plan = reducer.reduce(
            .panelInteraction(.setMenuBarHover(true)),
            state: synchronized
        )

        XCTAssertEqual(
            plan.nextState.overlayState.panelState.presentationState.displayState,
            .closed
        )
        let renderLists = plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            if case let .overlay(.renderIslandSurface(renderList)) = action { return renderList }
            return nil
        }
        XCTAssertEqual(renderLists.count, 1)
        XCTAssertEqual(renderLists[0].sections.displayStatus, .closed)
        XCTAssertFalse(renderLists[0].sections.visibleSections.contains(.expandedPanel))
    }

    func testSynchronizingPlacementReappliesFrameForCurrentExpandedState() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 624, y: 914, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 416, y: 630, width: 680, height: 320),
            anchor: DisplayPoint(x: 756, y: 950),
            safeAreaAdjustment: 32
        )
        let state = NotchViewModelState(
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(
                    presentationState: NotchPresentationState(
                        displayState: .expanded,
                        interactionState: PanelInteractionState(displayState: .expanded)
                    )
                )
            )
        )

        let plan = NotchViewModelReducer().reduce(.synchronizePlacement(placement), state: state)

        XCTAssertEqual(plan.actions, [
            .overlay(.applyPanelPlan(actions: [
                .applyFrame(placement.expandedFrame),
                .showPanel(displayState: .expanded),
            ])),
        ])
    }

    func testLocalPreferencesReplacementRoundTripsThroughState() {
        let preferences = NotchLocalUIPreferences(
            showUsageInPill: true,
            reduceMotion: true,
            compactMode: true
        )

        let plan = NotchViewModelReducer().reduce(.replaceLocalPreferences(preferences), state: NotchViewModelState())

        XCTAssertEqual(plan.nextState.localPreferences, preferences)
        XCTAssertEqual(plan.actions, [])
    }

    func testOriginalCompactRuntimeStateReplacementReachesCompactRenderBoundaryAndDefaultsLegacyJSON() throws {
        let runtimeState = OriginalCompactRuntimeState(
            isMinimized: true,
            notchWidthOffset: 4,
            notchHeightOffset: 3,
            completionFlashTick: 7
        )
        let presentation = NotchPresentationState(
            displayState: .closed,
            pillSnapshot: PillSnapshot(completedUnreadCount: 2),
            interactionState: PanelInteractionState(displayState: .closed, isHovering: true)
        )
        let state = NotchViewModelState(
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(
                    presentationState: presentation,
                    placementPlan: DisplayPlacementPlan(
                        closedFrame: DisplayFrame(x: 0, y: 0, width: 264, height: 36),
                        expandedFrame: DisplayFrame(x: 0, y: 0, width: 680, height: 580),
                        anchor: DisplayPoint(x: 132, y: 36),
                        safeAreaAdjustment: 18
                    )
                )
            ),
            localPreferences: NotchLocalUIPreferences(compactMode: true),
            autoExpandOnTaskComplete: false
        )

        let plan = NotchViewModelReducer().reduce(
            .replaceOriginalCompactRuntimeState(runtimeState),
            state: state
        )
        let renderList = try XCTUnwrap(plan.actions.compactMap { action -> IslandSurfaceRenderList? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList
        }.last)
        let compactItem = try XCTUnwrap(renderList.items.first { $0.section == .compactPill })

        XCTAssertEqual(plan.nextState.originalCompactRuntimeState, runtimeState)
        XCTAssertEqual(renderList.sections.originalCompactRuntimeState, runtimeState)
        XCTAssertEqual(compactItem.originalCompactRuntimeState, runtimeState)
        XCTAssertEqual(compactItem.displayStatus, .closed)
        XCTAssertEqual(compactItem.layoutMode, .compact)
        XCTAssertTrue(compactItem.isHovering)
        XCTAssertEqual(compactItem.safeAreaAdjustment, 18)
        XCTAssertTrue(compactItem.isCompletionUnreadOverviewVisible)

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(plan.nextState)) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "originalCompactRuntimeState")
        let decodedLegacyState = try JSONDecoder().decode(
            NotchViewModelState.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )

        XCTAssertEqual(decodedLegacyState.originalCompactRuntimeState, OriginalCompactRuntimeState())
        XCTAssertEqual(
            try JSONDecoder().decode(OriginalCompactRuntimeState.self, from: Data("{}".utf8)),
            OriginalCompactRuntimeState()
        )
    }

    func testIslandSurfaceSnapshotDecodesPayloadWithoutPostLegacyFields() throws {
        let snapshot = IslandSurfaceSnapshot(
            sessions: [fullSession(id: "session-1", command: "swift test")],
            originalCompactRuntimeState: OriginalCompactRuntimeState(isMinimized: true),
            displayStatus: .closed,
            layoutMode: .compact,
            focusedSessionId: nil,
            presentationState: NotchPresentationState(displayState: .closed),
            sessionSets: NotchSessionSets(),
            contentDimensions: NotchContentDimensions(),
            pillSnapshot: PillSnapshot(),
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(kind: .idle),
            actionRequestPreviews: [
                actionPreview(requestId: "permission-1", kind: .permission, prompt: "Allow?")
            ]
        )
        let data = try encodedJSON(
            snapshot,
            removing: ["sessions", "originalCompactRuntimeState", "actionRequestPreviews"]
        )

        let decoded = try JSONDecoder().decode(IslandSurfaceSnapshot.self, from: data)

        XCTAssertEqual(decoded.sessions, [])
        XCTAssertEqual(decoded.originalCompactRuntimeState, OriginalCompactRuntimeState())
        XCTAssertEqual(decoded.actionRequestPreviews, [])
    }

    func testIslandSurfaceSectionsDecodesPayloadWithoutPostLegacyFields() throws {
        let sections = IslandSurfaceSections(
            sessions: [fullSession(id: "session-1", command: "swift test")],
            visibleSections: [.compactPill],
            originalCompactRuntimeState: OriginalCompactRuntimeState(isMinimized: true),
            displayStatus: .expanded,
            layoutMode: .compact,
            isHovering: true,
            safeAreaAdjustment: 18,
            isCompletionUnreadOverviewVisible: true,
            onboardingStep: nil,
            primarySessionIds: ["session-1"],
            actionRequestPreviews: [
                actionPreview(requestId: "permission-1", kind: .permission, prompt: "Allow?")
            ]
        )
        let data = try encodedJSON(
            sections,
            removing: [
                "sessions",
                "originalCompactRuntimeState",
                "displayStatus",
                "layoutMode",
                "isHovering",
                "safeAreaAdjustment",
                "isCompletionUnreadOverviewVisible",
                "actionRequestPreviews",
            ]
        )

        let decoded = try JSONDecoder().decode(IslandSurfaceSections.self, from: data)

        XCTAssertEqual(decoded.sessions, [])
        XCTAssertEqual(decoded.originalCompactRuntimeState, OriginalCompactRuntimeState())
        XCTAssertEqual(decoded.displayStatus, .closed)
        XCTAssertEqual(decoded.layoutMode, .compact)
        XCTAssertFalse(decoded.isHovering)
        XCTAssertEqual(decoded.safeAreaAdjustment, 0)
        XCTAssertFalse(decoded.isCompletionUnreadOverviewVisible)
        XCTAssertEqual(decoded.actionRequestPreviews, [])
    }

    func testIslandSurfaceRenderItemDecodesPayloadWithoutPostLegacyFields() throws {
        let item = IslandSurfaceRenderItem(
            section: .compactPill,
            originalCompactRuntimeState: OriginalCompactRuntimeState(isMinimized: true),
            displayStatus: .expanded,
            layoutMode: .compact,
            isHovering: true,
            safeAreaAdjustment: 18,
            isCompletionUnreadOverviewVisible: true,
            sessionIds: ["session-1"],
            actionRequestPreviews: [
                actionPreview(requestId: "permission-1", kind: .permission, prompt: "Allow?")
            ],
            sessionPreviews: [preview(id: "session-1", status: .active)],
            sessions: [fullSession(id: "session-1", command: "swift test")]
        )
        let data = try encodedJSON(
            item,
            removing: [
                "originalCompactRuntimeState",
                "displayStatus",
                "layoutMode",
                "isHovering",
                "safeAreaAdjustment",
                "isCompletionUnreadOverviewVisible",
                "actionRequestPreviews",
                "sessionPreviews",
                "sessions",
            ]
        )

        let decoded = try JSONDecoder().decode(IslandSurfaceRenderItem.self, from: data)

        XCTAssertEqual(decoded.originalCompactRuntimeState, OriginalCompactRuntimeState())
        XCTAssertEqual(decoded.displayStatus, .closed)
        XCTAssertEqual(decoded.layoutMode, .compact)
        XCTAssertFalse(decoded.isHovering)
        XCTAssertEqual(decoded.safeAreaAdjustment, 0)
        XCTAssertFalse(decoded.isCompletionUnreadOverviewVisible)
        XCTAssertEqual(decoded.actionRequestPreviews, [])
        XCTAssertNil(decoded.sessionPreviews)
        XCTAssertEqual(decoded.sessions, [])
    }

    func testNotchViewModelStateDecodesPayloadWithoutPostLegacyFields() throws {
        let state = NotchViewModelState(
            sessions: [fullSession(id: "session-1", command: "swift test")],
            originalCompactRuntimeState: OriginalCompactRuntimeState(isMinimized: true),
            actionRequestPreviews: [
                actionPreview(requestId: "permission-1", kind: .permission, prompt: "Allow?")
            ]
        )
        let data = try encodedJSON(
            state,
            removing: ["sessions", "originalCompactRuntimeState", "actionRequestPreviews"]
        )

        let decoded = try JSONDecoder().decode(NotchViewModelState.self, from: data)

        XCTAssertEqual(decoded.sessions, [])
        XCTAssertEqual(decoded.originalCompactRuntimeState, OriginalCompactRuntimeState())
        XCTAssertEqual(decoded.actionRequestPreviews, [])
    }

    func testDisplayIntentFocusedSnapshotSummarizesCurrentIslandState() {
        let reducer = NotchViewModelReducer()
        let state = NotchViewModelState(
            sessionPreviews: [preview(id: "session-1", status: .active)],
            focusedSessionId: "session-1",
            localPreferences: NotchLocalUIPreferences(compactMode: true)
        )
        let plan = reducer.reduce(.showNotificationPeek([]), state: state)

        let snapshot = DisplayIntentFocusedSnapshot(state: plan.nextState)

        XCTAssertEqual(snapshot.focusedSessionId, "session-1")
        XCTAssertEqual(snapshot.displayStatus, .notificationPeek)
        XCTAssertEqual(snapshot.layoutMode, .compact)
        XCTAssertNil(snapshot.transientRevealKind)
        XCTAssertNil(snapshot.blockingKind)
    }

    func testDisplayIntentFocusedSnapshotReportsBlockingKind() {
        let onboarding = OnboardingState(currentStep: .demo)
        let plan = NotchViewModelReducer().reduce(
            .applyOnboardingState(onboarding),
            state: NotchViewModelState()
        )

        let snapshot = DisplayIntentFocusedSnapshot(state: plan.nextState)

        XCTAssertEqual(snapshot.displayStatus, .onboarding)
        XCTAssertEqual(snapshot.layoutMode, .compact)
        XCTAssertEqual(snapshot.blockingKind, .onboarding)
        XCTAssertNil(snapshot.transientRevealKind)
    }

    func testNotchSessionSetsSummarizeDeferredBypassedAndUnreadSessions() {
        let state = NotchViewModelState(
            sessionPreviews: [
                preview(id: "active", status: .active),
                preview(id: "restored", status: .idle, restored: true),
                preview(id: "missing-jump", status: .idle, jumpAvailable: false),
                preview(id: "unread", status: .completed, hasUnreadCompletion: true)
            ],
            focusedSessionId: "active",
            notificationPreviews: [
                preview(id: "notification-unread", status: .completed, hasUnreadCompletion: true)
            ]
        )

        let sets = NotchSessionSets(state: state)

        XCTAssertEqual(sets.visibleSessionIds, ["active", "restored", "missing-jump", "unread"])
        XCTAssertEqual(sets.focusedSessionId, "active")
        XCTAssertEqual(sets.deferredSessionIds, ["restored"])
        XCTAssertEqual(sets.bypassedSessionIds, ["missing-jump"])
        XCTAssertEqual(sets.unreadSessionIds, ["notification-unread", "unread"])
    }

    func testNotchContentDimensionsPreservePlacementPlanSizesWithoutSynthesizingCompactWidth() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 4, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 114, y: 20),
            safeAreaAdjustment: 12
        )

        let expanded = NotchContentDimensions(
            placementPlan: placement,
            displayStatus: .expanded
        )
        let closed = NotchContentDimensions(
            placementPlan: placement,
            displayStatus: .closed
        )

        XCTAssertEqual(expanded.closedSize, DisplaySize(width: 220, height: 36))
        XCTAssertEqual(expanded.expandedSize, DisplaySize(width: 640, height: 420))
        XCTAssertEqual(expanded.activeContentSize, DisplaySize(width: 640, height: 420))
        XCTAssertEqual(closed.activeContentSize, DisplaySize(width: 220, height: 36))
        XCTAssertNotEqual(closed.closedSize.width, 264)
        XCTAssertEqual(expanded.safeAreaAdjustment, 12)
    }

    func testIslandSurfaceSnapshotCollectsRenderableNotchState() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 4, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 114, y: 20),
            safeAreaAdjustment: 12
        )
        let state = NotchViewModelState(
            sessionPreviews: [
                preview(id: "active", status: .active),
                preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"])
            ],
            focusedSessionId: "active",
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(
                    presentationState: NotchPresentationBuilder().presentationState(
                        displayState: .notificationPeek,
                        previews: [
                            preview(id: "active", status: .active),
                            preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"])
                        ],
                        focusedSessionId: "active",
                        interactionState: PanelInteractionState(displayState: .notificationPeek),
                        notificationPreviews: [
                            preview(id: "done", status: .completed, hasUnreadCompletion: true)
                        ],
                        displayReason: .notificationPeek
                    ),
                    placementPlan: placement
                )
            ),
            onboardingState: OnboardingState(currentStep: .demo),
            questionSelections: QuestionSelectionState(selections: ["request-1": "approve"]),
            notificationPreviews: [
                preview(id: "done", status: .completed, hasUnreadCompletion: true)
            ]
        )

        let surface = IslandSurfaceSnapshot(state: state)

        XCTAssertEqual(surface.displayStatus, .notificationPeek)
        XCTAssertEqual(surface.layoutMode, .compact)
        XCTAssertEqual(surface.focusedSessionId, "active")
        XCTAssertEqual(surface.sessionSets.visibleSessionIds, ["active", "waiting"])
        XCTAssertEqual(surface.sessionSets.unreadSessionIds, ["done"])
        XCTAssertEqual(surface.contentDimensions.activeContentSize, DisplaySize(width: 220, height: 36))
        XCTAssertEqual(surface.pillSnapshot.waitingCount, 1)
        XCTAssertEqual(surface.stateIndicator.kind, .waiting)
        XCTAssertEqual(surface.completionUnreadDot.count, 0)
        XCTAssertTrue(surface.isNotificationPeekVisible)
        XCTAssertTrue(surface.isOnboardingActive)
        XCTAssertEqual(surface.onboardingStep, .demo)
        XCTAssertTrue(surface.hasQuestionSelections)
        XCTAssertEqual(surface.questionSelectionCount, 1)
    }

    func testIslandSurfaceKeepsRootContentStatusIndependentFromDisplayIntent() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 4, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 114, y: 20),
            safeAreaAdjustment: 12
        )
        let presentation = NotchPresentationBuilder().presentationState(
            displayState: .notificationPeek,
            rootContentStatus: .compact,
            previews: [preview(id: "active", status: .active)],
            focusedSessionId: "active",
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            notificationPreviews: [preview(id: "done", status: .completed, hasUnreadCompletion: true)],
            displayReason: .notificationPeek
        )
        let state = NotchViewModelState(
            sessionPreviews: [preview(id: "active", status: .active)],
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(
                    presentationState: presentation,
                    placementPlan: placement
                )
            )
        )

        let surface = IslandSurfaceSnapshot(state: state)
        let sections = IslandSurfaceSections(surface: surface)

        XCTAssertEqual(surface.displayStatus, .notificationPeek)
        XCTAssertEqual(surface.rootContentStatus, .compact)
        XCTAssertEqual(surface.contentDimensions.activeContentSize, DisplaySize(width: 220, height: 36))
        XCTAssertFalse(sections.visibleSections.contains(.expandedPanel))
        XCTAssertTrue(sections.visibleSections.contains(.notificationPeek))
    }

    func testIslandSurfaceSectionsDeriveVisibleUIRegions() {
        let active = preview(id: "active", status: .active)
        let waiting = preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"])
        let notification = preview(id: "done", status: .completed, hasUnreadCompletion: true)
        let permission = actionPreview(
            requestId: "request-1",
            kind: .permission,
            prompt: "Allow /usr/bin/whoami?"
        )
        let presentation = NotchPresentationBuilder().presentationState(
            displayState: .notificationPeek,
            previews: [active, waiting],
            focusedSessionId: "active",
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            usageDisplayState: usagePresentation(percent: 81).displayState,
            notificationPreviews: [notification],
            displayReason: .notificationPeek
        )
        let surface = IslandSurfaceSnapshot(
            displayStatus: .notificationPeek,
            layoutMode: .regular,
            focusedSessionId: "active",
            presentationState: presentation,
            sessionSets: NotchSessionSets(
                visibleSessionIds: ["active", "waiting"],
                focusedSessionId: "active",
                unreadSessionIds: ["done"]
            ),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                expandedSize: DisplaySize(width: 640, height: 420),
                activeContentSize: DisplaySize(width: 640, height: 420)
            ),
            pillSnapshot: presentation.pillSnapshot,
            completionUnreadDot: CompletionUnreadDot(count: 1),
            stateIndicator: StateIndicator(snapshot: presentation.pillSnapshot),
            usagePresentation: usagePresentation(percent: 81),
            isNotificationPeekVisible: true,
            isOnboardingActive: true,
            onboardingStep: .demo,
            hasQuestionSelections: true,
            questionSelectionCount: 1,
            actionRequestPreviews: [permission]
        )

        let sections = IslandSurfaceSections(surface: surface)

        XCTAssertEqual(sections.visibleSections, [
            .compactPill,
            .notificationPeek,
            .usageInfo,
            .onboardingGlow,
            .questionActions,
            .actionRequests
        ])
        XCTAssertEqual(sections.primarySessionIds, ["active", "waiting"])
        XCTAssertEqual(sections.notificationSessionIds, ["done"])
        XCTAssertEqual(sections.focusedSessionId, "active")
        XCTAssertEqual(sections.contentSize, DisplaySize(width: 640, height: 420))
        XCTAssertEqual(sections.rightSlotContent, .waitingAction(count: 1))
        XCTAssertEqual(sections.usageInfoBar, UsageInfoBar.make(displayState: usagePresentation(percent: 81).displayState))
        XCTAssertEqual(sections.onboardingStep, .demo)
        XCTAssertEqual(sections.questionSelectionCount, 1)
        XCTAssertEqual(sections.actionRequestPreviews, [permission])

        let renderList = IslandSurfaceRenderList(surface: surface)
        XCTAssertEqual(
            renderList.items.first(where: { $0.section == .actionRequests })?.actionRequestPreviews,
            [permission]
        )
    }

    func testIslandSurfaceSectionsIncludeVisibleUpdatePill() {
        let updatePill = UpdateAvailablePill(
            visible: true,
            label: "Update 2.0.0",
            targetVersion: "2.0.0",
            action: .openUpdateWindow
        )
        let surface = IslandSurfaceSnapshot(
            displayStatus: .closed,
            layoutMode: .regular,
            focusedSessionId: nil,
            presentationState: NotchPresentationState(displayState: .closed),
            sessionSets: NotchSessionSets(),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                activeContentSize: DisplaySize(width: 220, height: 36)
            ),
            pillSnapshot: PillSnapshot(visualState: .idle),
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(kind: .idle),
            updatePill: updatePill
        )

        let sections = IslandSurfaceSections(surface: surface)

        XCTAssertEqual(sections.visibleSections, [.compactPill, .updatePill])
        XCTAssertEqual(sections.updatePill, updatePill)
    }

    func testIslandSurfaceSectionsTreatPositiveQuestionSelectionCountAsVisibleActions() {
        let surface = IslandSurfaceSnapshot(
            displayStatus: .closed,
            layoutMode: .compact,
            focusedSessionId: nil,
            presentationState: NotchPresentationState(displayState: .closed),
            sessionSets: NotchSessionSets(visibleSessionIds: ["active"]),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                activeContentSize: DisplaySize(width: 220, height: 36)
            ),
            pillSnapshot: PillSnapshot(visualState: .idle),
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(kind: .idle),
            hasQuestionSelections: false,
            questionSelectionCount: 2
        )

        let sections = IslandSurfaceSections(surface: surface)

        XCTAssertTrue(sections.visibleSections.contains(.questionActions))
        XCTAssertEqual(sections.questionSelectionCount, 2)
    }

    func testIslandSurfaceSectionsExposeSwitcherRegion() {
        let active = preview(id: "active", status: .active)
        let presentation = NotchPresentationBuilder().presentationState(
            displayState: .switcher,
            previews: [active],
            focusedSessionId: "active",
            interactionState: PanelInteractionState(displayState: .switcher),
            displayReason: .keyboardShortcut
        )
        let surface = IslandSurfaceSnapshot(
            displayStatus: .switcher,
            layoutMode: .expanded,
            focusedSessionId: "active",
            presentationState: presentation,
            sessionSets: NotchSessionSets(visibleSessionIds: ["active"], focusedSessionId: "active"),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                expandedSize: DisplaySize(width: 640, height: 420),
                activeContentSize: DisplaySize(width: 640, height: 420)
            ),
            pillSnapshot: presentation.pillSnapshot,
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(snapshot: presentation.pillSnapshot)
        )

        let sections = IslandSurfaceSections(surface: surface)

        XCTAssertEqual(sections.visibleSections, [
            .compactPill,
            .expandedPanel,
            .sessionCards,
            .switcher
        ])
        XCTAssertEqual(sections.focusedSessionId, "active")
    }

    func testIslandSurfaceRenderListBuildsStableItemsForVisibleSections() {
        let active = preview(id: "active", status: .active)
        let waiting = preview(id: "waiting", status: .waiting, pendingRequestIds: ["request-1"])
        let notification = preview(id: "done", status: .completed, hasUnreadCompletion: true)
        let presentation = NotchPresentationBuilder().presentationState(
            displayState: .notificationPeek,
            previews: [active, waiting],
            focusedSessionId: "active",
            interactionState: PanelInteractionState(displayState: .notificationPeek),
            notificationPreviews: [notification],
            displayReason: .notificationPeek
        )
        let surface = IslandSurfaceSnapshot(
            displayStatus: .notificationPeek,
            layoutMode: .regular,
            focusedSessionId: "active",
            presentationState: presentation,
            sessionSets: NotchSessionSets(
                visibleSessionIds: ["active", "waiting"],
                focusedSessionId: "active",
                unreadSessionIds: ["done"]
            ),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                expandedSize: DisplaySize(width: 640, height: 420),
                activeContentSize: DisplaySize(width: 640, height: 420)
            ),
            pillSnapshot: presentation.pillSnapshot,
            completionUnreadDot: CompletionUnreadDot(count: 1),
            stateIndicator: StateIndicator(snapshot: presentation.pillSnapshot),
            isNotificationPeekVisible: true,
            hasQuestionSelections: true
        )

        let renderList = IslandSurfaceRenderList(surface: surface)

        XCTAssertEqual(renderList.items, [
            IslandSurfaceRenderItem(
                section: .compactPill,
                displayStatus: .notificationPeek,
                layoutMode: .regular,
                isCompletionUnreadOverviewVisible: true,
                sessionIds: ["active", "waiting"],
                focusedSessionId: "active",
                contentSize: DisplaySize(width: 640, height: 420),
                sessionPreviews: [active, waiting]
            ),
            IslandSurfaceRenderItem(
                section: .notificationPeek,
                displayStatus: .notificationPeek,
                layoutMode: .regular,
                isCompletionUnreadOverviewVisible: true,
                sessionIds: ["done"],
                focusedSessionId: "active",
                contentSize: DisplaySize(width: 640, height: 420),
                sessionPreviews: [notification]
            ),
            IslandSurfaceRenderItem(
                section: .questionActions,
                displayStatus: .notificationPeek,
                layoutMode: .regular,
                isCompletionUnreadOverviewVisible: true,
                sessionIds: ["active", "waiting"],
                focusedSessionId: "active",
                contentSize: DisplaySize(width: 640, height: 420),
                sessionPreviews: [active, waiting]
            )
        ])
    }

    func testIslandSurfaceRenderItemsExposeInteractionHints() {
        let sections = IslandSurfaceSections(
            visibleSections: [
                .compactPill,
                .notificationPeek,
                .updatePill,
                .switcher,
                .questionActions
            ],
            primarySessionIds: ["active"],
            notificationSessionIds: ["done"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 220, height: 36),
            updatePill: UpdateAvailablePill(visible: true, label: "Update 2.0.0", action: .openUpdateWindow)
        )

        let items = IslandSurfaceRenderList(sections: sections).items

        XCTAssertEqual(items.map(\.interactionHint), [
            .toggleExpandedPanel,
            .openNotificationSession,
            .openUpdateWindow,
            .switchFocusedSession,
            .answerQuestion
        ])
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = NotchViewModelState(
            sessionPreviews: [preview(id: "session-1", status: .active)],
            focusedSessionId: "session-1",
            usagePresentation: usagePresentation(),
            onboardingState: OnboardingState(currentStep: .demo),
            onboardingDemoState: OnboardingDemoRunnerState(defaultCwd: "/tmp/demo", activeSessionIds: ["demo"]),
            questionSelections: QuestionSelectionState(selections: ["request-1": "approve"]),
            notificationPreviews: [preview(id: "done", status: .completed, hasUnreadCompletion: true)],
            localPreferences: NotchLocalUIPreferences(showUsageInPill: true)
        )

        let decoded = try JSONDecoder().decode(
            NotchViewModelState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func preview(
        id: String,
        status: SessionStatus,
        pendingRequestIds: [String] = [],
        hasUnreadCompletion: Bool = false,
        restored: Bool = false,
        jumpAvailable: Bool = true,
        title: String? = nil
    ) -> SessionCardPreview {
        SessionCardPreview(
            session: AgentSession(
                id: id,
                source: "codex",
                cwd: jumpAvailable ? "/tmp/project" : "",
                safeTitle: title ?? "\(id) title",
                tasks: tasks(for: status),
                pendingRequestIds: pendingRequestIds,
                isRestored: restored,
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
                isRestored: restored
            )
        )
    }

    private func fullSession(id: String, command: String) -> AgentSession {
        AgentSession(
            id: id,
            source: "codex",
            cwd: "/tmp/\(id)",
            originalStatus: .runningTool,
            toolInput: ["command": .string(command)],
            firstUserMessage: "Work on \(id)"
        )
    }

    private func actionPreview(
        requestId: String,
        sessionId: String = "session-1",
        kind: ActionableRequestKind,
        prompt: String,
        options: [ActionRequestOption] = []
    ) -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: requestId,
            sessionId: sessionId,
            source: "codex",
            kind: kind,
            toolName: kind == .permission ? "Shell" : "Question",
            details: ActionRequestDetails(prompt: prompt, options: options)
        ))
    }

    private func encodedJSON<T: Encodable>(
        _ value: T,
        removing keys: [String]
    ) throws -> Data {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
        keys.forEach { object.removeValue(forKey: $0) }
        return try JSONSerialization.data(withJSONObject: object)
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

    private func usagePresentation(percent: Double = 50) -> UsagePresentationSnapshot {
        let displayState = UsageDisplayState(
            status: .available,
            providerDisplayName: "Codex",
            displayStyle: .ringBadge,
            valueMode: .used,
            title: "Codex",
            primaryText: "\(Int(percent))% used",
            percent: percent
        )
        return UsagePresentationSnapshot(
            selection: UsageProviderSelection(descriptor: nil, reason: .none),
            displayState: displayState
        )
    }
}

private struct NotchViewModelReducerMatrixFixture: Codable, Equatable {
    let rows: [NotchViewModelReducerMatrixRow]
}

private struct NotchViewModelReducerMatrixRow: Codable, Equatable {
    let id: String
    let sessionIds: [String]
    let notificationPreviewIds: [String]
    let focusedSessionId: String?
    let displayState: PanelDisplayState
    let visualState: PillVisualState
    let activeCount: Int
    let waitingCount: Int
    let usagePrimaryText: String?
    let rightSlotSummary: String
    let onboardingStep: OnboardingStep?
    let onboardingActive: Bool
    let questionSelectionCount: Int
    let lastRouteSummary: String?
    let actionSummaries: [String]

    init(id: String, plan: NotchViewModelPlan) {
        self.id = id
        let state = plan.nextState
        let presentation = state.overlayState.panelState.presentationState
        let pill = presentation.pillSnapshot

        sessionIds = state.sessionPreviews.map(\.sessionId)
        notificationPreviewIds = state.notificationPreviews.map(\.sessionId)
        focusedSessionId = state.focusedSessionId
        displayState = presentation.displayState
        visualState = pill.visualState
        activeCount = pill.activeCount
        waitingCount = pill.waitingCount
        usagePrimaryText = pill.usageInfoBar?.primaryText
        rightSlotSummary = Self.describe(pill.rightSlotContent)
        onboardingStep = state.onboardingState?.currentStep
        onboardingActive = presentation.interactionState.onboardingActive
        questionSelectionCount = state.questionSelections.selections.count
        lastRouteSummary = state.overlayState.lastRoutedAction.map(Self.describe(_:))
        actionSummaries = plan.actions.map(Self.describe(_:))
    }

    private static func describe(_ action: NotchViewModelAction) -> String {
        switch action {
        case let .overlay(overlayAction):
            return "overlay:\(describe(overlayAction))"
        case .refreshUsageDisplay:
            return "refreshUsageDisplay"
        case let .showNotificationPeek(previews):
            return "showNotificationPeek:\(previews.map(\.sessionId).joined(separator: ","))"
        case .clearNotificationPeek:
            return "clearNotificationPeek"
        case let .storeQuestionSelection(requestId, selection):
            return "storeQuestionSelection:\(requestId):\(selection)"
        }
    }

    private static func describe(_ action: OverlayControllerAction) -> String {
        switch action {
        case .renderPresentation:
            return "renderPresentation"
        case .renderIslandSurface:
            return "renderIslandSurface"
        case let .applyPanelPlan(actions):
            return "applyPanelPlan:\(actions.count)"
        case let .routeAction(route):
            return "routeAction:\(describe(route))"
        case let .recordDisplayReason(reason):
            return "recordDisplayReason:\(reason.rawValue)"
        }
    }

    private static func describe(_ route: OverlayRoutedAction) -> String {
        switch route {
        case let .selectSession(sessionId):
            return "selectSession:\(sessionId)"
        case let .jumpToSession(sessionId):
            return "jumpToSession:\(sessionId)"
        case let .resolveAction(requestId, sessionId):
            return "resolveAction:\(requestId):\(sessionId)"
        case let .answerQuestion(requestId, sessionId):
            return "answerQuestion:\(requestId):\(sessionId)"
        case let .submitActionResolution(resolution):
            return "submitActionResolution:\(resolution.requestId):\(resolution.kind.rawValue)"
        case let .appCommand(command):
            return "appCommand:\(command)"
        case .openSettings:
            return "openSettings"
        }
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
