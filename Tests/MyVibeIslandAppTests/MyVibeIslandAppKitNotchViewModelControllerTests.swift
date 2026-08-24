import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitNotchViewModelControllerTests: XCTestCase {
    func testRuntimeRefreshUsesOriginalIdleAutoHideDelayWithoutChangingPresentationState() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchViewModelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("private let autoHideWhenIdle: Bool"))
        XCTAssertTrue(source.contains("private var idleAutoHideTask: Task<Void, Never>?"))
        XCTAssertTrue(source.contains("Task.sleep(for: .seconds(2))"))
        XCTAssertTrue(source.contains("setIdleHidden(true)"))
        XCTAssertTrue(source.contains("setIdleHidden(false)"))
        XCTAssertTrue(source.contains("state.overlayState.panelState.presentationState.sessionPreviews"))
        XCTAssertFalse(source.contains(".panelInteraction(.transientReveal(reason: .autoHidden))"))
    }

    @MainActor
    func testEmptyDisplayCollectionHidesAfterOriginalDelayAndRestoresWithoutChangingDisplayState() async throws {
        var idleVisibilityChanges: [Bool] = []
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: MyVibeIslandAppKitOverlayController(),
            autoHideWhenIdle: true,
            setIdleHidden: { idleVisibilityChanges.append($0) }
        )

        controller.replaceSessionPreviews([])
        XCTAssertTrue(idleVisibilityChanges.isEmpty)

        let timeout = ContinuousClock.now.advanced(by: .seconds(3))
        while idleVisibilityChanges.isEmpty, ContinuousClock.now < timeout {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(idleVisibilityChanges, [true])
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )

        let preview = SessionCardPreview(session: AgentSession(
            id: "restored-session",
            source: "codex",
            cwd: "/tmp/project"
        ))
        controller.replaceSessionPreviews([preview])

        XCTAssertEqual(idleVisibilityChanges, [true, false])
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    func testInteractionReducerBoundaryEmitsHoverCommandAndResultTrace() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchViewModelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("hover.reducer_command"))
        XCTAssertTrue(source.contains("hover.reducer_result"))
        XCTAssertTrue(source.contains("hoverActionSummary"))
    }

    @MainActor
    func testApplyingUsagePresentationUpdatesStateAndRendersIslandSurface() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let usagePresentation = UsagePresentationSnapshot(
            selection: UsageProviderSelection(descriptor: nil, reason: .none),
            displayState: UsageDisplayState(
                status: .available,
                providerDisplayName: "Codex",
                displayStyle: .ringBadge,
                valueMode: .used,
                title: "Codex",
                primaryText: "73% used",
                percent: 73
            )
        )

        controller.applyUsagePresentation(usagePresentation)

        XCTAssertEqual(controller.state.usagePresentation, usagePresentation)
        XCTAssertEqual(controller.lastPlan?.nextState, controller.state)
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .usageInfo }?.detailLabel,
            "Codex: 73% used"
        )
    }

    @MainActor
    func testReplacingSessionPreviewsUpdatesStateAndRendersIslandSurface() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project"
        ))

        controller.replaceSessionPreviews([preview])

        XCTAssertEqual(controller.state.sessionPreviews, [preview])
        XCTAssertEqual(controller.lastPlan?.nextState, controller.state)
        XCTAssertEqual(descriptors.count, 1)
        XCTAssertEqual(
            try XCTUnwrap(descriptors.last).items.first?.sessionIds,
            ["session-1"]
        )
    }

    @MainActor
    func testTogglingManualSessionExpansionUpdatesModelStateAndRendersSurface() {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )

        controller.toggleManualSessionExpansion("session-1")

        XCTAssertEqual(controller.state.manuallyExpandedSessionIDs, ["session-1"])
        XCTAssertEqual(controller.lastPlan?.nextState, controller.state)
        XCTAssertEqual(descriptors.count, 1)
    }

    @MainActor
    func testNotificationPeekWrappersDispatchReducerActions() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "notification-session",
            source: "codex",
            cwd: "/tmp/project"
        ))

        controller.showNotificationPeek([preview])

        XCTAssertEqual(controller.state.notificationPreviews, [preview])
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .notificationPeek
        )
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .notificationPeek }?.sessionIds,
            ["notification-session"]
        )

        controller.clearNotificationPeek()

        XCTAssertTrue(controller.state.notificationPreviews.isEmpty)
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
        XCTAssertEqual(descriptors.count, 2)
    }

    @MainActor
    func testCompletionRenderUsesExpandedRootAndKeepsItsPreviewAddition() {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/project"
        ))
        controller.replaceSessionPreviews([preview])

        controller.showCompletionRender(sessionId: "completed")

        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
        XCTAssertEqual(controller.state.notificationPreviews, [preview])
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .sessionCards }?.sessionIds,
            ["completed"]
        )
    }

    @MainActor
    func testTaskCompletionWithoutAutoExpandIncrementsCompactFlashTickWithoutExpanding() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        ))
        controller.replaceSessionPreviews([preview])

        controller.handleTaskCompletion(
            sessionId: "completed",
            autoExpandOnTaskComplete: false
        )

        XCTAssertEqual(controller.state.originalCompactRuntimeState.completionFlashTick, 1)
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
        let compactItem = try XCTUnwrap(controller.lastPlan?.actions.compactMap { action -> IslandSurfaceRenderItem? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList.items.first { $0.section == .compactPill }
        }.last)
        XCTAssertEqual(compactItem.originalCompactRuntimeState.completionFlashTick, 1)
    }

    @MainActor
    func testTaskCompletionSuppressExpandPolicyRejectsCompactFlashAndExpansion() {
        let overlayController = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let session = AgentSession(
            id: "suppressed-completion",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        )
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)]
        ))

        controller.handleTaskCompletion(
            sessionId: session.id,
            autoExpandOnTaskComplete: false,
            sensoryPolicy: V3SensoryPolicy(
                hidePanel: false,
                muteSound: false,
                suppressExpand: true,
                autoDismissOnStop: false,
                matchedRuleIds: []
            )
        )

        XCTAssertEqual(controller.state.originalCompactRuntimeState.completionFlashTick, 0)
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    @MainActor
    func testCompletionNotificationEligibilityRejectsV3PolicyBeforeNonQuietRouting() {
        let overlayController = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let session = AgentSession(
            id: "suppressed-completion",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        )
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)]
        ))

        let policy = V3SensoryPolicy(
            hidePanel: true,
            muteSound: true,
            suppressExpand: true,
            autoDismissOnStop: false,
            matchedRuleIds: []
        )

        XCTAssertFalse(
            controller.allowsTaskCompletionNotification(
                sessionId: session.id,
                quietSceneActive: false,
                sensoryPolicy: policy
            )
        )
        XCTAssertTrue(
            controller.allowsTaskCompletionNotification(
                sessionId: session.id,
                quietSceneActive: true,
                sensoryPolicy: policy
            )
        )
    }

    @MainActor
    func testTaskCompletionExpandsWhenAnotherAppIsFrontmost() {
        let overlayController = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController,
            automaticExpansionFocus: { _ in
                V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys999"]
                )
            }
        )
        let session = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true,
            jumpInput: JumpInput(
                sessionId: "completed",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "ttys001"
            )
        )
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)]
        ))

        controller.handleTaskCompletion(
            sessionId: "completed",
            autoExpandOnTaskComplete: true
        )

        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
    }

    @MainActor
    func testTaskCompletionExpandsForRealTmuxPaneBeforeAClientAttaches() {
        let overlayController = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let session = AgentSession(
            id: "completed-headless-tmux",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true,
            jumpInput: JumpInput(
                sessionId: "completed-headless-tmux",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "ttys005",
                isInTmux: true,
                tmuxPane: "%231",
                tmuxSocketPath: "/private/tmp/tmux-502/no-attached-client"
            )
        )
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)]
        ))

        controller.handleTaskCompletion(
            sessionId: session.id,
            autoExpandOnTaskComplete: true
        )

        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
    }

    @MainActor
    func testTaskCompletionExpandsSameSessionListWhenForegroundTerminalMatches() {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController,
            automaticExpansionFocus: { _ in
                V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys001"]
                )
            }
        )
        let current = AgentSession(
            id: "current",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .processing
        )
        let completed = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true,
            jumpInput: JumpInput(
                sessionId: "completed",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "ttys001"
            )
        )
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [current, completed],
            sessionPreviews: [SessionCardPreview(session: current), SessionCardPreview(session: completed)]
        ))

        controller.handleTaskCompletion(
            sessionId: "completed",
            autoExpandOnTaskComplete: true
        )

        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
        XCTAssertEqual(controller.state.focusedSessionId, "completed")
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .sessionCards }?.sessionIds,
            ["current", "completed"]
        )
    }

    @MainActor
    func testQuietSceneCompletionSuppressesAutomaticCompletionRender() {
        let overlayController = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "quiet-completed",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        ))
        controller.replaceSessionPreviews([preview])

        controller.handleTaskCompletion(
            sessionId: "quiet-completed",
            autoExpandOnTaskComplete: true,
            quietSceneActive: true
        )

        XCTAssertTrue(controller.state.quietSceneCompletionPending)
        XCTAssertEqual(
            controller.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
        XCTAssertEqual(controller.state.originalCompactRuntimeState.completionFlashTick, 0)
    }

    @MainActor
    func testReplacingIslandRuntimeSnapshotPublishesOnlyFinalCombinedSurface() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let fullSession = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .runningTool,
            toolInput: ["command": .string("swift test")]
        )
        let session = SessionCardPreview(session: fullSession)
        let action = ActionRequestPreview(request: ActionableRequest(
            requestId: "permission-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Shell"
        ))

        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [fullSession],
            sessionPreviews: [session],
            actionRequestPreviews: [action]
        ))

        XCTAssertEqual(controller.state.sessions, [fullSession])
        XCTAssertEqual(controller.state.sessionPreviews, [session])
        XCTAssertEqual(controller.state.actionRequestPreviews, [action])
        XCTAssertEqual(descriptors.count, 1)
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .actionRequests }?.actionRequestPreviews,
            [action]
        )
        let compactItem = try XCTUnwrap(controller.lastPlan?.actions.compactMap { action -> IslandSurfaceRenderItem? in
            guard case let .overlay(.renderIslandSurface(renderList)) = action else {
                return nil
            }
            return renderList.items.first { $0.section == .compactPill }
        }.last)
        XCTAssertEqual(compactItem.sessions, [fullSession])
    }

    @MainActor
    func testCompletionRenderFocusSurvivesRuntimeRefreshes() throws {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let current = AgentSession(
            id: "current",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "启动新版本。",
            originalStatus: .processing
        )
        let completed = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "finished",
            originalStatus: .ended,
            hasUnreadCompletion: true
        )
        let snapshot = IslandRuntimeSnapshot(
            sessions: [current, completed],
            sessionPreviews: [SessionCardPreview(session: current), SessionCardPreview(session: completed)]
        )

        controller.replaceIslandRuntimeSnapshot(snapshot)
        controller.showCompletionRender(sessionId: "completed")

        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .sessionCards }?.sessionIds,
            ["current", "completed"]
        )
        controller.replaceIslandRuntimeSnapshot(snapshot)

        XCTAssertEqual(controller.state.focusedSessionId, "completed")
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .sessionCards }?.detailLabel,
            "Focused session: completed"
        )
        XCTAssertEqual(
            descriptors.last?.items.first { $0.section == .sessionCards }?.sessionIds,
            ["current", "completed"]
        )
    }

    @MainActor
    func testBlockingRuntimeSnapshotExpandsFrameAfterPlacementSynchronization() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 624, y: 914, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 416, y: 630, width: 680, height: 320),
            anchor: DisplayPoint(x: 756, y: 950),
            safeAreaAdjustment: 32
        )
        let overlayController = MyVibeIslandAppKitOverlayController()
        let controller = MyVibeIslandAppKitNotchViewModelController(
            overlayController: overlayController
        )
        let action = ActionRequestPreview(request: ActionableRequest(
            requestId: "permission-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Shell"
        ))

        controller.synchronizePlacement(placement)
        controller.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            actionRequestPreviews: [action]
        ))

        XCTAssertEqual(overlayController.lastAppliedFrame, placement.expandedFrame)
    }
}
