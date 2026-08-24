import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitNotificationPresentationControllerTests: XCTestCase {
    @MainActor
    func testNotificationPresentationControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotificationPresentationControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/notification-presentation-controller-matrix")
        )

        let actual = NotificationPresentationControllerMatrixFixture(rows: [
            row(
                id: "expanded-peek",
                actions: [
                    .presentPeek(Self.peek(id: "question-1", category: .questionAsked), .expanded)
                ]
            ),
            row(
                id: "unread-then-sound",
                actions: [
                    .markUnread(Self.peek(id: "permission-1", category: .permissionRequested)),
                    .requestSound(NotificationSoundRequest(
                        notificationId: "permission-1",
                        category: .permission,
                        source: "runtime"
                    ))
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPresentsPeekNotificationThroughInjectedClosure() {
        var rows: [PeekNotificationRow] = []
        let controller = MyVibeIslandAppKitNotificationPresentationController(
            presentPeek: { notification in
                rows.append(PeekNotificationRow(notification: notification))
            }
        )
        let notification = Self.peek(id: "question-1", category: .questionAsked)

        let presented = controller.presentPeek(notification, presentation: .expanded)

        XCTAssertEqual(presented.notification.id, "question-1")
        XCTAssertEqual(presented.presentation, .expanded)
        XCTAssertEqual(controller.lastAction, .presentPeek(presented))
        XCTAssertEqual(rows.map(\.id), ["question-1"])
        XCTAssertEqual(rows.first?.body, "Body")
    }

    @MainActor
    func testControllerPublishesUnreadAndSoundRequestsThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotificationPresentationController(
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )
        let notification = Self.peek(id: "permission-1", category: .permissionRequested)
        let soundRequest = NotificationSoundRequest(
            notificationId: notification.id,
            category: .permission,
            source: "runtime"
        )

        controller.markUnread(notification)
        controller.requestSound(soundRequest)

        XCTAssertEqual(controller.lastAction, .requestSound(soundRequest))
        XCTAssertEqual(events, [
            "unread:permission-1",
            "sound:permission-1:permission"
        ])
    }

    @MainActor
    func testCompletedPeekClearsAfterItsDwellWhileApprovalPeekDoesNotScheduleClear() async {
        var clearCount = 0
        let controller = MyVibeIslandAppKitNotificationPresentationController(
            clearPeek: { clearCount += 1 }
        )

        controller.presentPeek(Self.peek(id: "completion-1", category: .sessionCompleted, dwellSeconds: 0))
        await Task.yield()
        XCTAssertEqual(clearCount, 1)

        controller.presentPeek(Self.peek(id: "permission-1", category: .permissionRequested, dwellSeconds: 0))
        await Task.yield()
        XCTAssertEqual(clearCount, 1)
    }

    @MainActor
    func testCompletedPeekDoesNotClearWhileExpandedPanelIsHovered() async {
        let hoverState = HoverState()
        var clearCount = 0
        let controller = MyVibeIslandAppKitNotificationPresentationController(
            clearPeek: { clearCount += 1 },
            shouldClearPeek: { !hoverState.isHovered }
        )

        controller.presentPeek(Self.peek(id: "completion-1", category: .sessionCompleted, dwellSeconds: 0))
        await Task.yield()
        XCTAssertEqual(clearCount, 0)

        hoverState.isHovered = false
        controller.presentPeek(Self.peek(id: "completion-2", category: .sessionCompleted, dwellSeconds: 0))
        await Task.yield()
        XCTAssertEqual(clearCount, 1)
    }

    @MainActor
    private final class HoverState {
        var isHovered = true
    }

    private static func peek(
        id: String,
        category: NotificationEventCategory,
            dwellSeconds: Double = 6.0
    ) -> PeekNotification {
        PeekNotification(
            id: id,
            category: category,
            sessionId: "session-1",
            agent: "codex",
            title: "Title",
            body: "Body",
            severity: .warning,
            primaryAction: .jump,
            createdAt: "2026-07-08T18:00:00Z",
            dwellSeconds: dwellSeconds,
            source: "runtime"
        )
    }

    @MainActor
    private func row(
        id: String,
        actions: [NotificationPresentationControllerFixtureAction]
    ) -> NotificationPresentationControllerMatrixRow {
        var events: [String] = []
        var presentedRows: [PeekNotificationRow] = []
        let controller = MyVibeIslandAppKitNotificationPresentationController(
            presentPeek: { notification in
                presentedRows.append(PeekNotificationRow(notification: notification))
                events.append("peek:\(notification.notification.id):\(notification.presentation.rawValue)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )
        var actionResults: [String] = []

        for action in actions {
            switch action {
            case let .presentPeek(notification, presentation):
                let presented = controller.presentPeek(notification, presentation: presentation)
                actionResults.append(
                    "presented:\(presented.notification.id):"
                    + "\(presented.presentation.rawValue):\(presented.focusedField.rawValue)"
                )
            case let .markUnread(notification):
                controller.markUnread(notification)
                actionResults.append("unread:\(notification.id)")
            case let .requestSound(request):
                controller.requestSound(request)
                actionResults.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        }

        return NotificationPresentationControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            actionResults: actionResults,
            presentedRows: presentedRows.map(NotificationPresentedRowSummary.init),
            lastAction: controller.lastAction.map(NotificationPresentationActionSummary.init),
            events: events
        )
    }
}

private struct NotificationPresentationControllerMatrixFixture: Codable, Equatable {
    let rows: [NotificationPresentationControllerMatrixRow]
}

private struct NotificationPresentationControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let actionResults: [String]
    let presentedRows: [NotificationPresentedRowSummary]
    let lastAction: NotificationPresentationActionSummary?
    let events: [String]
}

private struct NotificationPresentedRowSummary: Codable, Equatable {
    let id: String
    let title: String
    let body: String?
    let severity: String
    let primaryAction: String?
    let focusedField: String

    init(_ row: PeekNotificationRow) {
        self.id = row.id
        self.title = row.title
        self.body = row.body
        self.severity = row.severity.rawValue
        self.primaryAction = row.primaryAction?.rawValue
        self.focusedField = row.focusedField.rawValue
    }
}

private struct NotificationPresentationActionSummary: Codable, Equatable {
    let kind: String
    let notificationId: String
    let presentation: String?
    let soundCategory: String?

    init(_ action: MyVibeIslandAppKitNotificationPresentationAction) {
        switch action {
        case let .presentPeek(notification):
            self.kind = "presentPeek"
            self.notificationId = notification.notification.id
            self.presentation = notification.presentation.rawValue
            self.soundCategory = nil
        case let .markUnread(notification):
            self.kind = "markUnread"
            self.notificationId = notification.id
            self.presentation = nil
            self.soundCategory = nil
        case let .requestSound(request):
            self.kind = "requestSound"
            self.notificationId = request.notificationId
            self.presentation = nil
            self.soundCategory = request.category.rawValue
        }
    }
}

private enum NotificationPresentationControllerFixtureAction {
    case presentPeek(PeekNotification, NotchPeekPresentation)
    case markUnread(PeekNotification)
    case requestSound(NotificationSoundRequest)

    var summary: String {
        switch self {
        case let .presentPeek(notification, presentation):
            return "presentPeek:\(notification.id):\(presentation.rawValue)"
        case let .markUnread(notification):
            return "markUnread:\(notification.id)"
        case let .requestSound(request):
            return "requestSound:\(request.notificationId):\(request.category.rawValue)"
        }
    }
}
