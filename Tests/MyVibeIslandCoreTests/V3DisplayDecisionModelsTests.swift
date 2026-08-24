import XCTest
@testable import MyVibeIslandCore

final class V3DisplayDecisionModelsTests: XCTestCase {
    func testRootResponseNotificationProducerDoesNotEmitBaselineOrDuplicateCompletion() {
        let session = producerSession(
            id: "codex-session-1",
            status: .completed,
            unread: false,
            assistant: "done"
        )
        let completed = producerSession(
            id: session.id,
            status: .completed,
            unread: true,
            assistant: "done"
        )
        var producer = V3RootResponseNotificationProducer()

        XCTAssertEqual(producer.ingest(producerSnapshot(session), now: date(10)), [])
        XCTAssertEqual(
            producer.ingest(producerSnapshot(completed), now: date(11)),
            [.init(sessionId: completed.id, effect: .revealProgress)]
        )
        XCTAssertEqual(producer.ingest(producerSnapshot(completed), now: date(12)), [])
    }

    func testRootResponseNotificationProducerUpdatesUnreadContentWithoutRevealingAgain() {
        let first = producerSession(
            id: "codex-session-1",
            status: .completed,
            unread: false,
            assistant: "first"
        )
        let second = producerSession(
            id: "codex-session-1",
            status: .completed,
            unread: true,
            assistant: "second"
        )
        var producer = V3RootResponseNotificationProducer()

        _ = producer.ingest(producerSnapshot(first), now: date(10))
        XCTAssertEqual(
            producer.ingest(producerSnapshot(second), now: date(11)),
            [.init(sessionId: second.id, effect: .revealProgress)]
        )
        XCTAssertEqual(
            producer.ingest(producerSnapshot(
                producerSession(
                    id: second.id,
                    status: .completed,
                    unread: true,
                    assistant: "third"
                )
            ), now: date(12)),
            []
        )
    }

    func testRootResponseNotificationProducerRetriesDeferredResponseWhenChildTreeSettles() {
        let runningParent = producerSession(
            id: "parent",
            status: .active,
            unread: false,
            assistant: "working",
            subagents: [producerChild(id: "child", status: "running")]
        )
        let deferredParent = producerSession(
            id: "parent",
            status: .completed,
            unread: true,
            assistant: "parent response",
            subagents: [producerChild(id: "child", status: "running")],
            pendingRequestIds: ["approval"]
        )
        let settledParent = producerSession(
            id: "parent",
            status: .completed,
            unread: true,
            assistant: "parent response",
            subagents: [producerChild(id: "child", status: "completed")]
        )
        var producer = V3RootResponseNotificationProducer()

        _ = producer.ingest(producerSnapshot(runningParent), now: date(10))
        XCTAssertEqual(producer.ingest(producerSnapshot(deferredParent), now: date(11)), [])
        XCTAssertEqual(
            producer.ingest(producerSnapshot(settledParent), now: date(12)),
            [.init(sessionId: "parent", effect: .revealFinal)]
        )
    }

    func testRootResponseNotificationProducerPrefersPublishedAuthoritativeChildMetadata() {
        let baseline = producerSession(
            id: "parent",
            status: .active,
            unread: false,
            assistant: "working",
            subagents: [producerChild(id: "child", status: "running")]
        )
        let completed = producerSession(
            id: "parent",
            status: .completed,
            unread: true,
            assistant: "done",
            subagents: [producerChild(id: "child", status: "running")]
        )
        let metadata = V3SessionNotificationMetadata(
            childTreeGeneration: 2,
            childLifecycleRevision: 4,
            childTreeHasAuthoritativeChildren: true,
            runningAuthoritativeChildCount: 0,
            hasSameTreeAttention: false
        )
        var producer = V3RootResponseNotificationProducer()

        _ = producer.ingest(producerSnapshot(baseline, metadata: ["parent": metadata]), now: date(10))
        XCTAssertEqual(
            producer.ingest(producerSnapshot(completed, metadata: ["parent": metadata]), now: date(11)),
            [.init(sessionId: "parent", effect: .revealFinal)]
        )
    }

    func testRootResponseNotificationProducerUsesConfiguredChildNotificationTiming() {
        let baseline = producerSession(
            id: "parent",
            status: .active,
            unread: false,
            assistant: "working",
            subagents: [producerChild(id: "child", status: "running")]
        )
        let response = producerSession(
            id: "parent",
            status: .completed,
            unread: true,
            assistant: "child still running",
            subagents: [producerChild(id: "child", status: "running")]
        )

        var allChildrenFinishedProducer = V3RootResponseNotificationProducer()
        _ = allChildrenFinishedProducer.ingest(producerSnapshot(baseline), now: date(10))
        XCTAssertEqual(
            allChildrenFinishedProducer.ingest(
                producerSnapshot(response),
                mode: .allChildrenFinished,
                now: date(11)
            ),
            []
        )

        var everyChildCompletionProducer = V3RootResponseNotificationProducer()
        _ = everyChildCompletionProducer.ingest(producerSnapshot(baseline), now: date(10))
        XCTAssertEqual(
            everyChildCompletionProducer.ingest(
                producerSnapshot(response),
                mode: .everyChildCompletion,
                now: date(11)
            ),
            [.init(sessionId: "parent", effect: .revealProgress)]
        )
    }

    private func producerSession(
        id: String,
        status: SessionStatus,
        unread: Bool,
        assistant: String,
        subagents: [SubagentState] = [],
        pendingRequestIds: [String] = []
    ) -> AgentSession {
        AgentSession(
            id: id,
            source: "codex",
            cwd: "/tmp",
            originalStatus: pendingRequestIds.isEmpty
                ? (status == .waiting ? .waitingForApproval : .ended)
                : .waitingForApproval,
            lastAssistantMessage: assistant,
            updatedAt: date(1),
            firstUserMessage: "request",
            lastUserMessage: "request",
            subagents: subagents,
            pendingRequestIds: pendingRequestIds,
            hasUnreadCompletion: unread
        )
    }

    private func producerChild(id: String, status: String) -> SubagentState {
        SubagentState(
            id: id,
            source: "codex",
            parentSessionId: "parent",
            parentThreadId: "parent",
            threadId: id,
            kind: "worker",
            nickname: nil,
            role: "worker",
            status: status,
            sourceDetailId: nil,
            startedAt: date(1),
            completedAt: status == "completed" ? date(2) : nil,
            hasLifecycleSignal: true,
            currentActivity: nil,
            needsAttention: false
        )
    }

    private func producerSnapshot(
        _ session: AgentSession,
        metadata: [String: V3SessionNotificationMetadata] = [:]
    ) -> IslandRuntimeSnapshot {
        IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)],
            v3NotificationMetadata: metadata
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    func testRootResponseNotificationDefersForSameTreeAttentionAfterRecordingNewResponse() {
        let initial = V3RootResponseNotificationState(
            runtimeInstanceId: 7,
            responseRevision: 4,
            lastResponseIdentity: "previous",
            lastNotifiedRevision: 2,
            lastViewedRevision: 2,
            becameUnreadAt: Date(timeIntervalSinceReferenceDate: 10),
            rootTurnGeneration: 3,
            finalNotifiedChildGeneration: nil,
            finalNotifiedRootTurnGeneration: nil
        )
        let context = V3RootResponseNotificationContext(
            sessionId: "session-1",
            runtimeInstanceId: 7,
            responseIdentity: "current",
            mode: .rootResponse,
            childTreeGeneration: 0,
            childLifecycleRevision: 0,
            childTreeHasAuthoritativeChildren: false,
            runningAuthoritativeChildCount: 0,
            hasSameTreeAttention: true
        )

        let result = V3RootResponseNotificationSelector.select(
            context: context,
            state: initial,
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(result.effect, .deferForAttention)
        XCTAssertEqual(result.state.responseRevision, 5)
        XCTAssertEqual(result.state.lastResponseIdentity, "current")
        XCTAssertEqual(result.state.becameUnreadAt, Date(timeIntervalSinceReferenceDate: 11))
    }

    func testRootResponseNotificationDoesNotMutateStateForDuplicateIdentity() {
        let initial = V3RootResponseNotificationState(
            runtimeInstanceId: 7,
            responseRevision: 4,
            lastResponseIdentity: "same",
            lastNotifiedRevision: 2,
            lastViewedRevision: 2,
            becameUnreadAt: Date(timeIntervalSinceReferenceDate: 10),
            rootTurnGeneration: 3,
            finalNotifiedChildGeneration: nil,
            finalNotifiedRootTurnGeneration: nil
        )
        let context = V3RootResponseNotificationContext(
            sessionId: "session-1",
            runtimeInstanceId: 7,
            responseIdentity: "same",
            mode: .rootResponse,
            childTreeGeneration: 0,
            childLifecycleRevision: 0,
            childTreeHasAuthoritativeChildren: false,
            runningAuthoritativeChildCount: 0,
            hasSameTreeAttention: false
        )

        let result = V3RootResponseNotificationSelector.select(
            context: context,
            state: initial,
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(result.effect, .duplicate)
        XCTAssertEqual(result.state, initial)
    }

    func testRootResponseNotificationRevealsProgressWhenPreviousNotificationWasViewed() {
        let result = V3RootResponseNotificationSelector.select(
            context: rootResponseContext(identity: "response-2"),
            state: rootResponseState(lastNotifiedRevision: 4, lastViewedRevision: 4),
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(result.effect, .revealProgress)
        XCTAssertEqual(result.state.responseRevision, 5)
        XCTAssertEqual(result.state.lastNotifiedRevision, 5)
    }

    func testRootResponseNotificationUpdatesOnlyWhenPreviousNotificationRemainsUnread() {
        let result = V3RootResponseNotificationSelector.select(
            context: rootResponseContext(identity: "response-2"),
            state: rootResponseState(lastNotifiedRevision: 4, lastViewedRevision: 3),
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(result.effect, .updateOnly)
        XCTAssertEqual(result.state.responseRevision, 5)
        XCTAssertEqual(result.state.lastNotifiedRevision, 5)
    }

    func testEveryChildCompletionUsesTheSameViewedRevisionDecisionAsRootResponse() {
        let context = V3RootResponseNotificationContext(
            sessionId: "session-1",
            runtimeInstanceId: 7,
            responseIdentity: "child-response-2",
            mode: .everyChildCompletion,
            childTreeGeneration: 2,
            childLifecycleRevision: 8,
            childTreeHasAuthoritativeChildren: true,
            runningAuthoritativeChildCount: 1,
            hasSameTreeAttention: false
        )

        let viewed = V3RootResponseNotificationSelector.select(
            context: context,
            state: rootResponseState(lastNotifiedRevision: 4, lastViewedRevision: 4),
            now: Date(timeIntervalSinceReferenceDate: 11)
        )
        let unread = V3RootResponseNotificationSelector.select(
            context: context,
            state: rootResponseState(lastNotifiedRevision: 4, lastViewedRevision: 3),
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(viewed.effect, .revealProgress)
        XCTAssertEqual(unread.effect, .updateOnly)
    }

    func testRootResponseNotificationRevealsFinalWhenAuthoritativeChildTreeSettlesForFirstTime() {
        let result = V3RootResponseNotificationSelector.select(
            context: V3RootResponseNotificationContext(
                sessionId: "session-1",
                runtimeInstanceId: 7,
                responseIdentity: "response-2",
                mode: .rootResponse,
                childTreeGeneration: 2,
                childLifecycleRevision: 8,
                childTreeHasAuthoritativeChildren: true,
                runningAuthoritativeChildCount: 0,
                hasSameTreeAttention: false
            ),
            state: rootResponseState(lastNotifiedRevision: 4, lastViewedRevision: 3),
            now: Date(timeIntervalSinceReferenceDate: 11)
        )

        XCTAssertEqual(result.effect, .revealFinal)
        XCTAssertEqual(result.state.finalNotifiedChildGeneration, 2)
        XCTAssertEqual(result.state.finalNotifiedRootTurnGeneration, 3)
    }

    func testTaskCompleteResolverRejectsWhenManualDisplayIsActive() {
        let decision = V3TaskCompleteDecisionResolver.resolve(
            sessionId: "completed",
            currentDisplayState: .manualExpanded
        )

        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.reason, "manual display active")
    }

    func testTaskCompleteResolverRejectsSuppressExpandSensoryPolicy() {
        let decision = V3TaskCompleteDecisionResolver.resolve(
            sessionId: "completed",
            currentDisplayState: .closed,
            policy: V3SensoryPolicy(
                hidePanel: false,
                muteSound: false,
                suppressExpand: true,
                autoDismissOnStop: false,
                matchedRuleIds: []
            )
        )

        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.reason, "suppressed by sensory policy")
        XCTAssertNil(decision.nextState)
        XCTAssertEqual(decision.expansion, V3DisplayExpansion.none)
    }

    func testTaskCompleteResolverRejectsHidePanelPolicyBeforeTransientDecision() {
        let decision = V3TaskCompleteDecisionResolver.resolve(
            sessionId: "completed",
            currentDisplayState: .closed,
            policy: V3SensoryPolicy(
                hidePanel: true,
                muteSound: true,
                suppressExpand: false,
                autoDismissOnStop: false,
                matchedRuleIds: []
            )
        )

        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.reason, "hidden session")
        XCTAssertNil(decision.nextState)
        XCTAssertEqual(decision.expansion, .none)
    }

    func testTaskCompleteResolverBuildsRecoveredTransientDecisionForAvailableDisplay() {
        let decision = V3TaskCompleteDecisionResolver.resolve(
            sessionId: "completed",
            currentDisplayState: .closed
        )

        XCTAssertEqual(
            decision,
            V3DisplayDecision(
                accepted: true,
                reason: "transient accepted",
                nextState: .transient,
                focus: .set("completed"),
                activeSessionId: .set("completed"),
                expansion: .expand,
                timerPolicy: .transient(.taskComplete),
                hoverPolicy: .shortCooldown
            )
        )
    }

    func testRecoveredDecisionContractPreservesV3PolicyCases() {
        XCTAssertEqual(V3DisplayFocusMutation.set("session-1"), .set("session-1"))
        XCTAssertEqual(V3DisplayFocusMutation.set(nil), .set(nil))
        XCTAssertEqual(V3DisplayFocusMutation.unchanged, .unchanged)

        XCTAssertEqual(
            V3DisplayExpansion.collapse(.autoTransient),
            .collapse(.autoTransient)
        )
        XCTAssertEqual(V3DisplayExpansion.none, .none)
        XCTAssertEqual(V3DisplayExpansion.expand, .expand)
        XCTAssertEqual(V3DisplayExpansion.peek, .peek)

        XCTAssertEqual(
            V3DisplayTimerPolicy.transient(.taskComplete),
            .transient(.taskComplete)
        )
        XCTAssertEqual(V3DisplayTimerPolicy.unchanged, .unchanged)
        XCTAssertEqual(V3DisplayTimerPolicy.cancel, .cancel)
        XCTAssertEqual(V3DisplayHoverPolicy.unchanged, .unchanged)
        XCTAssertEqual(V3DisplayHoverPolicy.shortCooldown, .shortCooldown)
    }

    func testConsumerAppliesRecoveredDecisionPoliciesInOriginalFieldOrder() {
        let decision = V3DisplayDecision(
            accepted: true,
            reason: "task complete",
            nextState: .transient,
            focus: .set("focus-session"),
            activeSessionId: .set("active-session"),
            expansion: .peek,
            timerPolicy: .transient(.taskComplete),
            hoverPolicy: .shortCooldown
        )

        let plan = V3DisplayDecisionConsumer.plan(decision, now: 42)

        XCTAssertEqual(
            plan.operations,
            [
                .setNextState(.transient),
                .setFocus("focus-session"),
                .setActiveSessionId("active-session"),
                .applyExpansion(.peek),
                .scheduleTransientTimer(.taskComplete),
                .startShortHoverCooldown(until: 42.6),
            ]
        )
    }

    func testConsumerLeavesFocusAndHoverUntouchedForUnchangedPolicies() {
        let decision = V3DisplayDecision(
            accepted: true,
            reason: "no presentation mutation",
            nextState: nil,
            focus: .unchanged,
            activeSessionId: .unchanged,
            expansion: .none,
            timerPolicy: .cancel,
            hoverPolicy: .unchanged
        )

        XCTAssertEqual(
            V3DisplayDecisionConsumer.plan(decision, now: 100).operations,
            []
        )
    }

    func testTaskCompletionPlanFlashesOnlyAfterAnAcceptedDecisionWhenAutoExpandIsDisabled() {
        let decision = taskCompleteDecision(accepted: true)

        let plan = V3TaskCompletionConsumer.plan(
            V3TaskCompletionInput(
                onboardingActive: false,
                blockingExpanded: false,
                targetSessionExists: true,
                targetSessionIsComplete: true,
                quietSceneActive: false,
                autoExpandOnTaskComplete: false,
                decision: decision,
                automaticExpansionGateAccepted: false
            )
        )

        XCTAssertEqual(plan, .incrementCompletionFlash)
    }

    func testTaskCompletionPlanLeavesAcceptedDecisionUnconsumedWhenAutomaticGateRejects() {
        let decision = taskCompleteDecision(accepted: true)

        let plan = V3TaskCompletionConsumer.plan(
            V3TaskCompletionInput(
                onboardingActive: false,
                blockingExpanded: false,
                targetSessionExists: true,
                targetSessionIsComplete: true,
                quietSceneActive: false,
                autoExpandOnTaskComplete: true,
                decision: decision,
                automaticExpansionGateAccepted: false
            )
        )

        XCTAssertEqual(plan, .leaveAcceptedDecisionUnconsumed)
    }

    func testTaskCompletionPlanConsumesOnlyAcceptedGateApprovedDecisions() {
        let decision = taskCompleteDecision(accepted: true)

        let plan = V3TaskCompletionConsumer.plan(
            V3TaskCompletionInput(
                onboardingActive: false,
                blockingExpanded: false,
                targetSessionExists: true,
                targetSessionIsComplete: true,
                quietSceneActive: false,
                autoExpandOnTaskComplete: true,
                decision: decision,
                automaticExpansionGateAccepted: true
            )
        )

        XCTAssertEqual(plan, .consumeDecision(decision))
    }

    func testTaskCompletionPlanRejectsBeforePresentationForOnboardingBlockingMissingOrIncompleteSession() {
        let decision = taskCompleteDecision(accepted: true)
        let base = V3TaskCompletionInput(
            onboardingActive: false,
            blockingExpanded: false,
            targetSessionExists: true,
            targetSessionIsComplete: true,
            quietSceneActive: false,
            autoExpandOnTaskComplete: true,
            decision: decision,
            automaticExpansionGateAccepted: true
        )

        XCTAssertEqual(
            V3TaskCompletionConsumer.plan(
                V3TaskCompletionInput(base: base, onboardingActive: true)
            ),
            .suppressed(.onboarding)
        )
        XCTAssertEqual(
            V3TaskCompletionConsumer.plan(
                V3TaskCompletionInput(base: base, blockingExpanded: true)
            ),
            .suppressed(.blockingExpanded)
        )
        XCTAssertEqual(
            V3TaskCompletionConsumer.plan(
                V3TaskCompletionInput(base: base, targetSessionExists: false)
            ),
            .suppressed(.missingTargetSession)
        )
        XCTAssertEqual(
            V3TaskCompletionConsumer.plan(
                V3TaskCompletionInput(base: base, targetSessionIsComplete: false)
            ),
            .suppressed(.targetNotComplete)
        )
    }

    func testTaskCompletionPlanMarksQuietScenePendingBeforeDecisionConsumption() {
        let plan = V3TaskCompletionConsumer.plan(
            V3TaskCompletionInput(
                onboardingActive: false,
                blockingExpanded: false,
                targetSessionExists: true,
                targetSessionIsComplete: true,
                quietSceneActive: true,
                autoExpandOnTaskComplete: true,
                decision: taskCompleteDecision(accepted: true),
                automaticExpansionGateAccepted: true
            )
        )

        XCTAssertEqual(plan, .markQuietScenePending)
    }

    private func taskCompleteDecision(accepted: Bool) -> V3DisplayDecision {
        V3DisplayDecision(
            accepted: accepted,
            reason: "task complete",
            nextState: .transient,
            focus: .set("session-1"),
            activeSessionId: .set("session-1"),
            expansion: .expand,
            timerPolicy: .transient(.taskComplete),
            hoverPolicy: .unchanged
        )
    }

    private func rootResponseState(
        lastNotifiedRevision: Int,
        lastViewedRevision: Int
    ) -> V3RootResponseNotificationState {
        V3RootResponseNotificationState(
            runtimeInstanceId: 7,
            responseRevision: 4,
            lastResponseIdentity: "response-1",
            lastNotifiedRevision: lastNotifiedRevision,
            lastViewedRevision: lastViewedRevision,
            becameUnreadAt: Date(timeIntervalSinceReferenceDate: 10),
            rootTurnGeneration: 3,
            finalNotifiedChildGeneration: nil,
            finalNotifiedRootTurnGeneration: nil
        )
    }

    private func rootResponseContext(identity: String) -> V3RootResponseNotificationContext {
        V3RootResponseNotificationContext(
            sessionId: "session-1",
            runtimeInstanceId: 7,
            responseIdentity: identity,
            mode: .rootResponse,
            childTreeGeneration: 0,
            childLifecycleRevision: 0,
            childTreeHasAuthoritativeChildren: false,
            runningAuthoritativeChildCount: 0,
            hasSameTreeAttention: false
        )
    }
}
