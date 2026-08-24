import XCTest
@testable import MyVibeIslandCore

final class NotificationWatcherModelsTests: XCTestCase {
    func testNotificationWatcherPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotificationWatcherPlanMatrixFixture.self,
            from: try FixtureLoader.data("notifications/watcher-plan-matrix")
        )
        let event = NotificationWatcherEvent(
            id: "permission-1",
            category: .permissionRequested,
            sessionId: "session-1",
            agent: "codex",
            title: "Permission requested",
            body: "Agent needs approval",
            severity: .blocking,
            primaryAction: .approve,
            secondaryAction: .deny,
            createdAt: "2026-07-08T08:00:00Z",
            dedupeKey: "permission:session-1",
            soundCategory: .permission,
            source: .runtime
        )
        let model = NotificationWatcherModel()

        let actual = NotificationWatcherPlanMatrixFixture(rows: [
            row(
                id: "start-not-determined",
                model.plan(.start, from: NotificationWatcherState(authorizationStatus: .notDetermined))
            ),
            row(
                id: "start-authorized",
                model.plan(.start, from: NotificationWatcherState(authorizationStatus: .authorized))
            ),
            row(
                id: "start-already-observing",
                model.plan(.start, from: NotificationWatcherState(authorizationStatus: .authorized, isObserving: true))
            ),
            row(
                id: "authorization-denied-stops-observing",
                model.plan(
                    .authorizationChanged(.denied),
                    from: NotificationWatcherState(authorizationStatus: .authorized, isObserving: true)
                )
            ),
            row(
                id: "receive-authorized-observing",
                model.plan(
                    .receive(event),
                    from: NotificationWatcherState(
                        authorizationStatus: .authorized,
                        isObserving: true,
                        pendingPeekIds: ["existing"]
                    )
                )
            ),
            row(
                id: "receive-not-authorized",
                model.plan(.receive(event), from: NotificationWatcherState(authorizationStatus: .denied))
            ),
            row(
                id: "receive-not-observing",
                model.plan(.receive(event), from: NotificationWatcherState(authorizationStatus: .authorized))
            ),
            row(
                id: "stop-observing",
                model.plan(
                    .stop,
                    from: NotificationWatcherState(
                        authorizationStatus: .authorized,
                        isObserving: true,
                        pendingPeekIds: ["permission-1"]
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testStartRequestsAuthorizationWhenStatusIsUnknown() {
        let model = NotificationWatcherModel()
        let plan = model.plan(
            .start,
            from: NotificationWatcherState(authorizationStatus: .notDetermined)
        )

        XCTAssertEqual(plan.nextState.authorizationStatus, .notDetermined)
        XCTAssertFalse(plan.nextState.isObserving)
        XCTAssertEqual(plan.actions, [.requestAuthorization])
    }

    func testStartRegistersObserverWhenAuthorized() {
        let model = NotificationWatcherModel()
        let plan = model.plan(
            .start,
            from: NotificationWatcherState(authorizationStatus: .authorized)
        )

        XCTAssertTrue(plan.nextState.isObserving)
        XCTAssertEqual(plan.actions, [.registerObserver])
    }

    func testReceiveNotificationPublishesPeekWhenObservingAndAuthorized() {
        let model = NotificationWatcherModel()
        let event = NotificationWatcherEvent(
            id: "permission-1",
            category: .permissionRequested,
            sessionId: "session-1",
            agent: "codex",
            title: "Permission requested",
            body: "Agent needs approval",
            severity: .blocking,
            primaryAction: .approve,
            secondaryAction: .deny,
            createdAt: "2026-07-08T08:00:00Z",
            dedupeKey: "permission:session-1",
            soundCategory: .permission,
            source: .runtime
        )

        let plan = model.plan(
            .receive(event),
            from: NotificationWatcherState(
                authorizationStatus: .authorized,
                isObserving: true
            )
        )

        XCTAssertEqual(plan.nextState.pendingPeekIds, ["permission-1"])
        XCTAssertEqual(plan.actions, [.publishPeek(event.peekNotification)])
    }

    func testReceiveNotificationIsSuppressedWhenWatcherIsNotObserving() {
        let event = NotificationWatcherEvent(
            id: "activity-1",
            category: .activityUpdate,
            title: "Activity",
            body: "Ignored while stopped",
            severity: .info,
            createdAt: "2026-07-08T08:00:00Z",
            source: .runtime
        )

        let plan = NotificationWatcherModel().plan(
            .receive(event),
            from: NotificationWatcherState(authorizationStatus: .authorized)
        )

        XCTAssertEqual(plan.nextState.pendingPeekIds, [])
        XCTAssertEqual(plan.actions, [.suppress(eventId: "activity-1", reason: .notObserving)])
    }

    private func row(
        id: String,
        _ plan: NotificationWatcherPlan
    ) -> NotificationWatcherPlanMatrixRow {
        NotificationWatcherPlanMatrixRow(
            id: id,
            nextState: plan.nextState,
            actions: plan.actions.map(actionSummary)
        )
    }

    private func actionSummary(_ action: NotificationWatcherAction) -> NotificationWatcherActionSummary {
        switch action {
        case .requestAuthorization:
            return NotificationWatcherActionSummary(kind: "requestAuthorization")
        case .registerObserver:
            return NotificationWatcherActionSummary(kind: "registerObserver")
        case .unregisterObserver:
            return NotificationWatcherActionSummary(kind: "unregisterObserver")
        case let .publishPeek(notification):
            return NotificationWatcherActionSummary(
                kind: "publishPeek",
                notificationId: notification.id,
                category: notification.category
            )
        case let .suppress(eventId, reason):
            return NotificationWatcherActionSummary(
                kind: "suppress",
                eventId: eventId,
                suppressionReason: reason
            )
        }
    }

    private struct NotificationWatcherPlanMatrixFixture: Codable, Equatable {
        let rows: [NotificationWatcherPlanMatrixRow]
    }

    private struct NotificationWatcherPlanMatrixRow: Codable, Equatable {
        let id: String
        let nextState: NotificationWatcherState
        let actions: [NotificationWatcherActionSummary]
    }

    private struct NotificationWatcherActionSummary: Codable, Equatable {
        let kind: String
        let notificationId: String?
        let category: NotificationEventCategory?
        let eventId: String?
        let suppressionReason: NotificationWatcherSuppressionReason?

        init(
            kind: String,
            notificationId: String? = nil,
            category: NotificationEventCategory? = nil,
            eventId: String? = nil,
            suppressionReason: NotificationWatcherSuppressionReason? = nil
        ) {
            self.kind = kind
            self.notificationId = notificationId
            self.category = category
            self.eventId = eventId
            self.suppressionReason = suppressionReason
        }
    }
}
