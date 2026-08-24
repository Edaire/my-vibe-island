import XCTest
@testable import MyVibeIslandCore

final class AgentWatcherModelsTests: XCTestCase {
    func testAgentWatcherMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AgentWatcherMatrixFixture.self,
            from: try FixtureLoader.data("agents/watcher-matrix")
        )
        let watcher = AgentWatcher(sourceIds: ["opencode", "codex", "codex"])
        let state = AgentWatcherState(
            watchedSourceIds: ["codex"],
            isRunning: true,
            pendingEvents: [
                AgentWatcherScheduledEvent(
                    id: "queued",
                    sourceId: "codex",
                    kind: .rescan,
                    scheduledAt: "2026-07-08T18:59:00Z"
                )
            ],
            lastScanAt: "2026-07-08T18:58:00Z"
        )
        let start = watcher.plan(.start, from: AgentWatcherState())
        let rescan = watcher.plan(.rescan(sourceId: "codex", at: "2026-07-08T19:01:00Z"), from: start.nextState)
        let unknown = watcher.plan(.rescan(sourceId: "unknown", at: "2026-07-08T19:02:00Z"), from: state)
        let stop = watcher.plan(.stop, from: state)
        let decoded = try JSONDecoder().decode(
            AgentWatcherState.self,
            from: try JSONEncoder().encode(state)
        )

        let cases = [
            AgentWatcherCase(
                name: "state-normalizes-and-round-trips",
                projection: AgentWatcherProjection(state: decoded, emittedEvents: [], action: nil)
            ),
            AgentWatcherCase(
                name: "start-watches-configured-sources",
                projection: AgentWatcherProjection(start)
            ),
            AgentWatcherCase(
                name: "rescan-emits-event-without-queueing",
                projection: AgentWatcherProjection(rescan)
            ),
            AgentWatcherCase(
                name: "unknown-source-rescan-is-ignored",
                projection: AgentWatcherProjection(unknown)
            ),
            AgentWatcherCase(
                name: "stop-clears-pending-events",
                projection: AgentWatcherProjection(stop)
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testAgentWatcherStateRoundTripsWatchedSourcesAndPendingEvents() throws {
        let state = AgentWatcherState(
            watchedSourceIds: ["codex", "opencode"],
            isRunning: true,
            pendingEvents: [
                AgentWatcherScheduledEvent(id: "rescan-1", sourceId: "codex", kind: .rescan, scheduledAt: "2026-07-08T19:00:00Z")
            ],
            lastScanAt: "2026-07-08T18:59:00Z"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AgentWatcherState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.watchedSourceIds, ["codex", "opencode"])
    }

    func testAgentWatcherPlansStartStopAndRescan() {
        let watcher = AgentWatcher(sourceIds: ["opencode", "codex", "codex"])

        let start = watcher.plan(.start, from: AgentWatcherState())
        XCTAssertEqual(start.action, .start)
        XCTAssertTrue(start.nextState.isRunning)
        XCTAssertEqual(start.nextState.watchedSourceIds, ["codex", "opencode"])

        let rescan = watcher.plan(.rescan(sourceId: "codex", at: "2026-07-08T19:01:00Z"), from: start.nextState)
        XCTAssertEqual(rescan.action, .rescan)
        XCTAssertEqual(rescan.emittedEvents.map(\.sourceId), ["codex"])
        XCTAssertEqual(rescan.nextState.lastScanAt, "2026-07-08T19:01:00Z")

        let stop = watcher.plan(.stop, from: rescan.nextState)
        XCTAssertFalse(stop.nextState.isRunning)
        XCTAssertTrue(stop.nextState.pendingEvents.isEmpty)
    }

    func testAgentWatcherIgnoresUnknownSourceRescanWithoutChangingState() {
        let watcher = AgentWatcher(sourceIds: ["codex"])
        let state = AgentWatcherState(watchedSourceIds: ["codex"], isRunning: true)

        let plan = watcher.plan(.rescan(sourceId: "unknown", at: "2026-07-08T19:02:00Z"), from: state)

        XCTAssertEqual(plan.action, .ignoreUnknownSource)
        XCTAssertEqual(plan.nextState, state)
        XCTAssertEqual(plan.emittedEvents, [])
    }

    private struct AgentWatcherMatrixFixture: Codable, Equatable {
        let cases: [AgentWatcherCase]
    }

    private struct AgentWatcherCase: Codable, Equatable {
        let name: String
        let projection: AgentWatcherProjection
    }

    private struct AgentWatcherProjection: Codable, Equatable {
        let action: AgentWatcherPlanAction?
        let watchedSourceIds: [String]
        let isRunning: Bool
        let pendingEventIds: [String]
        let lastScanAt: String?
        let emittedEventIds: [String]
        let emittedSourceIds: [String]

        init(_ plan: AgentWatcherPlan) {
            self.init(state: plan.nextState, emittedEvents: plan.emittedEvents, action: plan.action)
        }

        init(
            state: AgentWatcherState,
            emittedEvents: [AgentWatcherScheduledEvent],
            action: AgentWatcherPlanAction?
        ) {
            self.action = action
            self.watchedSourceIds = state.watchedSourceIds
            self.isRunning = state.isRunning
            self.pendingEventIds = state.pendingEvents.map(\.id)
            self.lastScanAt = state.lastScanAt
            self.emittedEventIds = emittedEvents.map(\.id)
            self.emittedSourceIds = emittedEvents.map(\.sourceId)
        }
    }
}
