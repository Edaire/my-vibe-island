import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitWhatsNewControllerTests: XCTestCase {
    @MainActor
    func testWhatsNewControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            WhatsNewControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/whats-new-controller-matrix")
        )

        let actual = WhatsNewControllerMatrixFixture(rows: [
            row(
                id: "version-change-shows-sanitized-content",
                initialState: WhatsNewStoreState(lastLaunchedVersion: "1.0.0"),
                commands: [
                    .recordLaunch(
                        currentVersion: "1.1.0",
                        rawHTML: #"<h1 onclick="run()">News</h1><script>alert("x")</script><p>Done</p>"#
                    )
                ]
            ),
            row(
                id: "unchanged-version-keeps-state",
                initialState: WhatsNewStoreState(lastLaunchedVersion: "1.1.0"),
                commands: [
                    .recordLaunch(currentVersion: "1.1.0", rawHTML: "<p>Same</p>")
                ]
            ),
            row(
                id: "dismiss-existing-pending-content",
                initialState: WhatsNewStoreState(
                    pendingHTML: "<p>Pending</p>",
                    pendingVersion: "1.2.0",
                    pendingPreviousVersion: "1.1.0",
                    lastLaunchedVersion: "1.2.0"
                ),
                commands: [.dismissPending]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPresentsSanitizedWhatsNewForVersionChangeAndDismissesIt() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitWhatsNewController(
            state: WhatsNewStoreState(lastLaunchedVersion: "1.0.0"),
            presentWhatsNew: { state in
                events.append("present:\(state.pendingVersion ?? "none"):\(state.pendingHTML ?? "none")")
            },
            dismissWhatsNew: {
                events.append("dismiss")
            }
        )

        let shown = controller.recordLaunch(
            currentVersion: "1.1.0",
            rawHTML: #"<h1 onclick="run()">News</h1><script>alert("x")</script><p>Done</p>"#
        )
        let dismissed = controller.dismissPending()

        XCTAssertEqual(shown.action, .showWhatsNew)
        XCTAssertEqual(dismissed.action, .dismissWhatsNew)
        XCTAssertNil(controller.state.pendingHTML)
        XCTAssertEqual(controller.state.lastLaunchedVersion, "1.1.0")
        XCTAssertEqual(events, [
            "present:1.1.0:<h1>News</h1><p>Done</p>",
            "dismiss"
        ])
    }

    @MainActor
    func testControllerDoesNotPresentWhenVersionIsUnchanged() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitWhatsNewController(
            state: WhatsNewStoreState(lastLaunchedVersion: "1.0.0"),
            presentWhatsNew: { _ in
                events.append("present")
            },
            dismissWhatsNew: {
                events.append("dismiss")
            }
        )

        let plan = controller.recordLaunch(currentVersion: "1.0.0", rawHTML: "<p>Same</p>")

        XCTAssertEqual(plan.action, .noChange)
        XCTAssertEqual(controller.state.lastLaunchedVersion, "1.0.0")
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testControllerPublishesLastWhatsNewStorePlanForOrchestration() {
        let controller = MyVibeIslandAppKitWhatsNewController(
            state: WhatsNewStoreState(lastLaunchedVersion: "1.0.0"),
            presentWhatsNew: { _ in },
            dismissWhatsNew: {}
        )

        _ = controller.recordLaunch(currentVersion: "1.1.0", rawHTML: "<p>News</p>")

        XCTAssertEqual(controller.lastPlan?.action, .showWhatsNew)
        XCTAssertEqual(controller.lastPlan?.nextState.pendingVersion, "1.1.0")
    }

    @MainActor
    private func row(
        id: String,
        initialState: WhatsNewStoreState,
        commands: [WhatsNewControllerFixtureCommand]
    ) -> WhatsNewControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitWhatsNewController(
            state: initialState,
            presentWhatsNew: { state in
                events.append("present:\(state.pendingVersion ?? "none"):\(state.pendingHTML ?? "none")")
            },
            dismissWhatsNew: {
                events.append("dismiss")
            }
        )
        var planActions: [String] = []

        for command in commands {
            switch command {
            case let .recordLaunch(currentVersion, rawHTML):
                let plan = controller.recordLaunch(currentVersion: currentVersion, rawHTML: rawHTML)
                planActions.append(plan.action.rawValue)
            case .dismissPending:
                let plan = controller.dismissPending()
                planActions.append(plan.action.rawValue)
            }
        }

        return WhatsNewControllerMatrixRow(
            id: id,
            initialState: WhatsNewStoreStateSummary(initialState),
            commands: commands.map(\.summary),
            planActions: planActions,
            finalState: WhatsNewStoreStateSummary(controller.state),
            lastPlanAction: controller.lastPlan?.action.rawValue,
            events: events
        )
    }
}

private struct WhatsNewControllerMatrixFixture: Codable, Equatable {
    let rows: [WhatsNewControllerMatrixRow]
}

private struct WhatsNewControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialState: WhatsNewStoreStateSummary
    let commands: [String]
    let planActions: [String]
    let finalState: WhatsNewStoreStateSummary
    let lastPlanAction: String?
    let events: [String]
}

private struct WhatsNewStoreStateSummary: Codable, Equatable {
    let pendingHTML: String?
    let pendingVersion: String?
    let pendingPreviousVersion: String?
    let lastLaunchedVersion: String?

    init(_ state: WhatsNewStoreState) {
        self.pendingHTML = state.pendingHTML
        self.pendingVersion = state.pendingVersion
        self.pendingPreviousVersion = state.pendingPreviousVersion
        self.lastLaunchedVersion = state.lastLaunchedVersion
    }
}

private enum WhatsNewControllerFixtureCommand {
    case recordLaunch(currentVersion: String, rawHTML: String?)
    case dismissPending

    var summary: String {
        switch self {
        case let .recordLaunch(currentVersion, rawHTML):
            return "recordLaunch:\(currentVersion):\(rawHTML ?? "nil")"
        case .dismissPending:
            return "dismissPending"
        }
    }
}
