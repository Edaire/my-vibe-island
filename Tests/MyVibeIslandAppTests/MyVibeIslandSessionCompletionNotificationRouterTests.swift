import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

final class MyVibeIslandSessionCompletionNotificationRouterTests: XCTestCase {
    @MainActor
    func testFirstSnapshotSeedsWithoutRevealingHistoricalUnreadCompletion() {
        let router = MyVibeIslandSessionCompletionNotificationRouter(
            createdAt: { "2026-07-18T00:00:00Z" }
        )

        let notifications = router.notifications(for: snapshot(
            preview(id: "restored", unread: true)
        ))

        XCTAssertTrue(notifications.isEmpty)
    }

    @MainActor
    func testNewUnreadTransitionEmitsOnceAndCanEmitAfterMarkerClears() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter(
            createdAt: { "2026-07-18T00:00:00Z" }
        )
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let first = try XCTUnwrap(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true)
        )).first)

        XCTAssertEqual(first.id, "session-1:completion")
        XCTAssertEqual(first.category, .sessionCompleted)
        XCTAssertEqual(first.sessionId, "session-1")
        XCTAssertEqual(first.agent, "codex")
        XCTAssertEqual(first.title, "Session session-1")
        XCTAssertEqual(first.body, "Finished work")
        XCTAssertEqual(first.primaryAction, .jump)
        XCTAssertEqual(first.createdAt, "2026-07-18T00:00:00Z")
        XCTAssertEqual(first.dedupeKey, "session-1:completion")
        XCTAssertEqual(first.soundCategory, .completion)
        XCTAssertEqual(first.rootResponseEffect, .revealProgress)
        XCTAssertTrue(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true)
        )).isEmpty)

        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))
        XCTAssertEqual(
            router.notifications(for: snapshot(preview(id: "session-1", unread: true))).count,
            1
        )
    }

    @MainActor
    func testReappearingHistoricalUnreadSessionDoesNotEmit() {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: true)))
        _ = router.notifications(for: snapshot())

        let notifications = router.notifications(for: snapshot(
            preview(id: "session-1", unread: true)
        ))

        XCTAssertTrue(notifications.isEmpty)
    }

    @MainActor
    func testNewUnreadSessionAppearingAfterBaselineEmitsCompletion() {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(preview(id: "existing-session", unread: false)))

        let notifications = router.notifications(for: snapshot(
            preview(id: "existing-session", unread: false),
            preview(id: "new-session", unread: true, updatedAt: Date(timeIntervalSince1970: 2_000))
        ))

        XCTAssertEqual(notifications.map(\.sessionId), ["new-session"])
    }

    @MainActor
    func testMultipleUnreadTransitionsEmitOnlyTheFirstVisibleCompletion() {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(
            preview(id: "current-session", unread: false),
            preview(id: "background-session", unread: false)
        ))

        let notifications = router.notifications(for: snapshot(
            preview(id: "current-session", unread: true),
            preview(id: "background-session", unread: true)
        ))

        XCTAssertEqual(notifications.map(\.sessionId), ["current-session"])
    }

    @MainActor
    func testCompletionBodyUsesTheCompletedSessionAssistantMessage() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter(
            createdAt: { "2026-07-18T00:00:00Z" }
        )
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is working.",
            lastAssistantMessage: "真实的完成回复",
            hasUnreadCompletion: true
        )
        let notification = try XCTUnwrap(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true),
            sessions: [session]
        )).first)

        XCTAssertEqual(notification.body, "真实的完成回复")
    }

    @MainActor
    func testCompletionNotificationUsesConfiguredDwellSeconds() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter(
            completionDwellSeconds: 3.25
        )
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let notification = try XCTUnwrap(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true)
        )).first)

        XCTAssertEqual(notification.dwellSeconds, 3.25)
    }

    @MainActor
    func testCompletionNotificationDefaultsToIDACompletionDwell() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let notification = try XCTUnwrap(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true)
        )).first)

        XCTAssertEqual(notification.dwellSeconds, 5.0)
    }

    @MainActor
    func testCompletionBodyFallsBackToCurrentCommandWhenAssistantMessageIsMissing() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is working.",
            currentCommandPreview: "git status",
            hasUnreadCompletion: true
        )
        let notification = try XCTUnwrap(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true),
            sessions: [session]
        )).first)

        XCTAssertEqual(notification.body, "git status")
    }

    @MainActor
    func testCompletionWithOnlySyntheticActivityDoesNotPublishAnEmptyShell() {
        let router = MyVibeIslandSessionCompletionNotificationRouter()
        _ = router.notifications(for: snapshot(preview(id: "session-1", unread: false)))

        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex completed the turn.",
            hasUnreadCompletion: true
        )

        XCTAssertTrue(router.notifications(for: snapshot(
            preview(id: "session-1", unread: true),
            sessions: [session]
        )).isEmpty)
    }

    @MainActor
    func testNewPermissionRequestEmitsOneOrdinaryIslandNotification() throws {
        let router = MyVibeIslandSessionCompletionNotificationRouter(
            createdAt: { "2026-07-30T00:00:00Z" }
        )
        let session = preview(id: "permission-session", unread: false)
        _ = router.notifications(for: snapshot(session))

        let notification = try XCTUnwrap(router.notifications(for: snapshot(
            session,
            actionRequests: [permissionRequest(sessionId: session.sessionId)]
        )).first)

        XCTAssertEqual(notification.id, "permission-1:permission")
        XCTAssertEqual(notification.category, .permissionRequested)
        XCTAssertEqual(notification.sessionId, session.sessionId)
        XCTAssertEqual(notification.title, session.displayTitle)
        XCTAssertEqual(notification.body, "Allow date command?")
        XCTAssertEqual(notification.primaryAction, .jump)
        XCTAssertNil(notification.secondaryAction)
        XCTAssertEqual(notification.soundCategory, .permission)
        XCTAssertTrue(router.notifications(for: snapshot(
            session,
            actionRequests: [permissionRequest(sessionId: session.sessionId)]
        )).isEmpty)
    }

    private func snapshot(
        _ previews: SessionCardPreview...,
        sessions: [AgentSession] = [],
        actionRequests: [ActionRequestPreview] = []
    ) -> IslandRuntimeSnapshot {
        IslandRuntimeSnapshot(
            sessions: sessions,
            sessionPreviews: previews,
            actionRequestPreviews: actionRequests
        )
    }

    private func preview(id: String, unread: Bool, updatedAt: Date? = nil) -> SessionCardPreview {
        SessionCardPreview(session: AgentSession(
            id: id,
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Finished work",
            updatedAt: updatedAt,
            customTitle: "Session \(id)",
            hasUnreadCompletion: unread
        ))
    }

    private func permissionRequest(sessionId: String) -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: "permission-1",
            sessionId: sessionId,
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(prompt: "Allow date command?")
        ))
    }
}
