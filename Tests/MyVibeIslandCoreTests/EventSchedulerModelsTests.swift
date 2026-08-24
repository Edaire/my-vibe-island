import XCTest
@testable import MyVibeIslandCore

final class EventSchedulerModelsTests: XCTestCase {
    func testEventSchedulerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            EventSchedulerMatrixFixture.self,
            from: try FixtureLoader.data("events/scheduler-matrix")
        )
        let scheduler = EventScheduler()
        let initial = EventSchedulerState(pendingTasks: [
            EventSchedulerTask(
                id: "cleanup:old-session:1000",
                key: "old-session",
                kind: .cleanup,
                dueAtMillis: 1_000,
                sourceId: "codex",
                sessionId: "old-session"
            ),
            EventSchedulerTask(
                id: "debounce:codex:file-delta:1250",
                key: "codex:file-delta",
                kind: .debounce,
                dueAtMillis: 1_250,
                sourceId: "codex"
            ),
            EventSchedulerTask(
                id: "throttle:screen-focus:1400",
                key: "screen-focus",
                kind: .throttle,
                dueAtMillis: 1_400
            )
        ])

        let cases = [
            EventSchedulerCase(
                name: "reschedule-debounce-cancels-existing-key",
                plan: EventSchedulerPlanProjection(scheduler.plan(
                    .scheduleDebounce(key: "codex:file-delta", delayMillis: 250, sourceId: "codex"),
                    from: initial,
                    nowMillis: 1_100
                ))
            ),
            EventSchedulerCase(
                name: "schedule-blocking-timeout-keeps-existing-tasks",
                plan: EventSchedulerPlanProjection(scheduler.plan(
                    .scheduleBlockingTimeout(requestId: "req-1", delayMillis: 30_000, sourceId: "opencode"),
                    from: initial,
                    nowMillis: 2_000
                ))
            ),
            EventSchedulerCase(
                name: "active-throttle-window-suppresses-duplicate",
                plan: EventSchedulerPlanProjection(scheduler.plan(
                    .openThrottleWindow(key: "screen-focus", intervalMillis: 500, sourceId: nil),
                    from: initial,
                    nowMillis: 1_200
                ))
            ),
            EventSchedulerCase(
                name: "collect-due-emits-non-throttle-only",
                plan: EventSchedulerPlanProjection(scheduler.plan(.collectDue, from: initial, nowMillis: 1_400))
            ),
            EventSchedulerCase(
                name: "cancel-removes-all-tasks-for-key",
                plan: EventSchedulerPlanProjection(scheduler.plan(.cancel(key: "screen-focus"), from: initial, nowMillis: 1_200))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testDebounceCoalescesByKeyAndEmitsOnlyDueTask() {
        let scheduler = EventScheduler()
        let initial = EventSchedulerState()

        let first = scheduler.plan(
            .scheduleDebounce(key: "codex:file-delta", delayMillis: 250, sourceId: "codex"),
            from: initial,
            nowMillis: 1_000
        )
        let second = scheduler.plan(
            .scheduleDebounce(key: "codex:file-delta", delayMillis: 250, sourceId: "codex"),
            from: first.nextState,
            nowMillis: 1_120
        )

        XCTAssertEqual(second.nextState.pendingTasks.count, 1)
        XCTAssertEqual(second.canceledTaskIds, ["debounce:codex:file-delta:1250"])
        XCTAssertEqual(second.nextState.pendingTasks.first?.id, "debounce:codex:file-delta:1370")

        let early = scheduler.plan(.collectDue, from: second.nextState, nowMillis: 1_300)
        XCTAssertEqual(early.emittedTasks, [])
        XCTAssertEqual(early.nextState.pendingTasks.count, 1)

        let due = scheduler.plan(.collectDue, from: second.nextState, nowMillis: 1_370)
        XCTAssertEqual(due.emittedTasks.map(\.id), ["debounce:codex:file-delta:1370"])
        XCTAssertEqual(due.nextState.pendingTasks, [])
    }

    func testTimeoutAndCleanupScheduleIndependentTasks() {
        let scheduler = EventScheduler()
        let timeout = scheduler.plan(
            .scheduleBlockingTimeout(requestId: "req-1", delayMillis: 30_000, sourceId: "opencode"),
            from: EventSchedulerState(),
            nowMillis: 2_000
        )
        let cleanup = scheduler.plan(
            .scheduleSessionCleanup(sessionId: "session-1", delayMillis: 600_000, sourceId: "codex"),
            from: timeout.nextState,
            nowMillis: 2_500
        )

        XCTAssertEqual(cleanup.nextState.pendingTasks.map(\.id), [
            "timeout:req-1:32000",
            "cleanup:session-1:602500"
        ])
        XCTAssertEqual(cleanup.nextState.pendingTasks.map(\.kind), [.timeout, .cleanup])
    }

    func testThrottleOpensWindowThenSuppressesUntilDue() {
        let scheduler = EventScheduler()
        let first = scheduler.plan(
            .openThrottleWindow(key: "screen-focus", intervalMillis: 500, sourceId: nil),
            from: EventSchedulerState(),
            nowMillis: 10_000
        )

        XCTAssertEqual(first.emittedTasks.map(\.kind), [.throttle])
        XCTAssertEqual(first.nextState.pendingTasks.map(\.id), ["throttle:screen-focus:10500"])

        let suppressed = scheduler.plan(
            .openThrottleWindow(key: "screen-focus", intervalMillis: 500, sourceId: nil),
            from: first.nextState,
            nowMillis: 10_100
        )

        XCTAssertEqual(suppressed.emittedTasks, [])
        XCTAssertEqual(suppressed.nextState.pendingTasks, first.nextState.pendingTasks)

        let collected = scheduler.plan(.collectDue, from: suppressed.nextState, nowMillis: 10_500)
        XCTAssertEqual(collected.emittedTasks, [])
        XCTAssertEqual(collected.nextState.pendingTasks, [])

        let reopened = scheduler.plan(
            .openThrottleWindow(key: "screen-focus", intervalMillis: 500, sourceId: nil),
            from: collected.nextState,
            nowMillis: 10_600
        )

        XCTAssertEqual(reopened.emittedTasks.map(\.id), ["throttle:screen-focus:10600"])
    }

    func testCancelRemovesAllTasksForKey() {
        let scheduler = EventScheduler()
        let state = EventSchedulerState(pendingTasks: [
            EventSchedulerTask(id: "a", key: "same", kind: .debounce, dueAtMillis: 1),
            EventSchedulerTask(id: "b", key: "same", kind: .cleanup, dueAtMillis: 2),
            EventSchedulerTask(id: "c", key: "other", kind: .timeout, dueAtMillis: 3)
        ])

        let plan = scheduler.plan(.cancel(key: "same"), from: state, nowMillis: 0)

        XCTAssertEqual(plan.canceledTaskIds, ["a", "b"])
        XCTAssertEqual(plan.nextState.pendingTasks.map(\.id), ["c"])
    }

    private struct EventSchedulerMatrixFixture: Codable, Equatable {
        let cases: [EventSchedulerCase]
    }

    private struct EventSchedulerCase: Codable, Equatable {
        let name: String
        let plan: EventSchedulerPlanProjection
    }

    private struct EventSchedulerPlanProjection: Codable, Equatable {
        let nextState: EventSchedulerState
        let emittedTasks: [EventSchedulerTask]
        let canceledTaskIds: [String]

        init(_ plan: EventSchedulerPlan) {
            self.nextState = plan.nextState
            self.emittedTasks = plan.emittedTasks
            self.canceledTaskIds = plan.canceledTaskIds
        }
    }
}
