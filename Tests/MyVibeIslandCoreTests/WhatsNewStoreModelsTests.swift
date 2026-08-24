import XCTest
@testable import MyVibeIslandCore

final class WhatsNewStoreModelsTests: XCTestCase {
    func testWhatsNewStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            WhatsNewStoreMatrixFixture.self,
            from: try FixtureLoader.data("runtime/whats-new-store-matrix")
        )
        let store = WhatsNewStore()
        let previous = WhatsNewStoreState(lastLaunchedVersion: "1.0.0")
        let shown = store.plan(
            .recordLaunch(
                currentVersion: "2.0.0",
                rawHTML: #"<h1 onclick="run()">News</h1><script>alert("x")</script><p>Done</p>"#
            ),
            from: previous
        )

        let actual = WhatsNewStoreMatrixFixture(rows: [
            WhatsNewStoreMatrixRow(
                id: "unchanged-launch",
                plan: store.plan(.recordLaunch(currentVersion: "1.0.0", rawHTML: "<p>Same</p>"), from: previous)
            ),
            WhatsNewStoreMatrixRow(
                id: "changed-launch-sanitized",
                plan: shown
            ),
            WhatsNewStoreMatrixRow(
                id: "changed-launch-empty-content",
                plan: store.plan(.recordLaunch(currentVersion: "1.1.0", rawHTML: nil), from: previous)
            ),
            WhatsNewStoreMatrixRow(
                id: "dismiss-pending",
                plan: store.plan(.dismissPending, from: shown.nextState)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testStoreCreatesPendingWhatsNewOnlyWhenLaunchedVersionChanges() {
        let store = WhatsNewStore()
        let state = WhatsNewStoreState(lastLaunchedVersion: "1.0.0")

        let unchanged = store.plan(
            .recordLaunch(currentVersion: "1.0.0", rawHTML: "<p>Same</p>"),
            from: state
        )
        let changed = store.plan(
            .recordLaunch(currentVersion: "1.1.0", rawHTML: "<p>New</p>"),
            from: state
        )

        XCTAssertEqual(unchanged.action, .noChange)
        XCTAssertNil(unchanged.nextState.pendingVersion)
        XCTAssertEqual(changed.action, .showWhatsNew)
        XCTAssertEqual(changed.nextState.pendingVersion, "1.1.0")
        XCTAssertEqual(changed.nextState.pendingPreviousVersion, "1.0.0")
        XCTAssertEqual(changed.nextState.pendingHTML, "<p>New</p>")
        XCTAssertEqual(changed.nextState.lastLaunchedVersion, "1.1.0")
    }

    func testStoreSanitizesUnsafeHTMLAndDismissesPendingContent() {
        let store = WhatsNewStore()
        let shown = store.plan(
            .recordLaunch(
                currentVersion: "2.0.0",
                rawHTML: #"<h1 onclick="run()">News</h1><script>alert("x")</script><p>Done</p>"#
            ),
            from: WhatsNewStoreState(lastLaunchedVersion: "1.0.0")
        )

        XCTAssertEqual(shown.nextState.pendingHTML, "<h1>News</h1><p>Done</p>")

        let dismissed = store.plan(.dismissPending, from: shown.nextState)

        XCTAssertEqual(dismissed.action, .dismissWhatsNew)
        XCTAssertNil(dismissed.nextState.pendingHTML)
        XCTAssertNil(dismissed.nextState.pendingVersion)
        XCTAssertNil(dismissed.nextState.pendingPreviousVersion)
        XCTAssertEqual(dismissed.nextState.lastLaunchedVersion, "2.0.0")
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = WhatsNewStoreState(
            pendingHTML: "<p>Updated</p>",
            pendingVersion: "3.0.0",
            pendingPreviousVersion: "2.0.0",
            lastLaunchedVersion: "3.0.0"
        )

        let decoded = try JSONDecoder().decode(
            WhatsNewStoreState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }
}

private struct WhatsNewStoreMatrixFixture: Codable, Equatable {
    let rows: [WhatsNewStoreMatrixRow]
}

private struct WhatsNewStoreMatrixRow: Codable, Equatable {
    let id: String
    let action: WhatsNewStoreAction
    let pendingHTML: String?
    let pendingVersion: String?
    let pendingPreviousVersion: String?
    let lastLaunchedVersion: String?

    init(id: String, plan: WhatsNewStorePlan) {
        self.id = id
        action = plan.action
        pendingHTML = plan.nextState.pendingHTML
        pendingVersion = plan.nextState.pendingVersion
        pendingPreviousVersion = plan.nextState.pendingPreviousVersion
        lastLaunchedVersion = plan.nextState.lastLaunchedVersion
    }
}
