import XCTest
@testable import MyVibeIslandCore

final class UpdateCheckerModelsTests: XCTestCase {
    func testUpdateCheckerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UpdateCheckerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/update-checker-matrix")
        )
        let checker = UpdateChecker()

        let actual = UpdateCheckerMatrixFixture(rows: [
            UpdateCheckerMatrixRow(
                id: "manual-check-disables-automatic-install",
                plan: checker.plan(
                    .manualCheck(currentVersion: "1.0.0"),
                    settings: UpdateCheckerSettings(
                        automaticChecksEnabled: false,
                        automaticInstallEnabled: true
                    )
                )
            ),
            UpdateCheckerMatrixRow(
                id: "background-check-disabled",
                plan: checker.plan(
                    .backgroundCheck(currentVersion: "1.0.0"),
                    settings: UpdateCheckerSettings(automaticChecksEnabled: false)
                )
            ),
            UpdateCheckerMatrixRow(
                id: "background-check-enabled-manual-install",
                plan: checker.plan(
                    .backgroundCheck(currentVersion: "1.0.0"),
                    settings: UpdateCheckerSettings(
                        automaticChecksEnabled: true,
                        automaticInstallEnabled: false
                    )
                )
            ),
            UpdateCheckerMatrixRow(
                id: "background-check-enabled-automatic-install",
                plan: checker.plan(
                    .backgroundCheck(currentVersion: "2.0.0"),
                    settings: UpdateCheckerSettings(
                        automaticChecksEnabled: true,
                        automaticInstallEnabled: true
                    )
                )
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testManualCheckAlwaysStartsWithMinimalRequestMetadata() {
        let checker = UpdateChecker()

        let plan = checker.plan(
            .manualCheck(currentVersion: "1.0.0"),
            settings: UpdateCheckerSettings(
                automaticChecksEnabled: false,
                automaticInstallEnabled: true
            )
        )

        XCTAssertEqual(plan.action, .startManualCheck)
        XCTAssertEqual(plan.request, UpdateCheckRequest(
            kind: .manual,
            currentVersion: "1.0.0",
            automaticInstallAllowed: false
        ))
    }

    func testBackgroundCheckRequiresExplicitAutomaticChecksSetting() {
        let checker = UpdateChecker()

        let disabled = checker.plan(
            .backgroundCheck(currentVersion: "1.0.0"),
            settings: UpdateCheckerSettings(automaticChecksEnabled: false)
        )
        let enabled = checker.plan(
            .backgroundCheck(currentVersion: "1.0.0"),
            settings: UpdateCheckerSettings(
                automaticChecksEnabled: true,
                automaticInstallEnabled: true
            )
        )

        XCTAssertEqual(disabled.action, .skipBackgroundCheck)
        XCTAssertNil(disabled.request)
        XCTAssertEqual(enabled.action, .startBackgroundCheck)
        XCTAssertEqual(enabled.request?.kind, .background)
        XCTAssertEqual(enabled.request?.automaticInstallAllowed, true)
    }

    func testSettingsAndRequestRoundTripThroughJSON() throws {
        let settings = UpdateCheckerSettings(automaticChecksEnabled: true, automaticInstallEnabled: false)
        let request = UpdateCheckRequest(
            kind: .background,
            currentVersion: "2.0.0",
            automaticInstallAllowed: false
        )

        let decodedSettings = try JSONDecoder().decode(
            UpdateCheckerSettings.self,
            from: try JSONEncoder().encode(settings)
        )
        let decodedRequest = try JSONDecoder().decode(
            UpdateCheckRequest.self,
            from: try JSONEncoder().encode(request)
        )

        XCTAssertEqual(decodedSettings, settings)
        XCTAssertEqual(decodedRequest, request)
    }
}

private struct UpdateCheckerMatrixFixture: Codable, Equatable {
    let rows: [UpdateCheckerMatrixRow]
}

private struct UpdateCheckerMatrixRow: Codable, Equatable {
    let id: String
    let action: UpdateCheckerAction
    let requestKind: UpdateCheckKind?
    let currentVersion: String?
    let automaticInstallAllowed: Bool?

    init(id: String, plan: UpdateCheckerPlan) {
        self.id = id
        action = plan.action
        requestKind = plan.request?.kind
        currentVersion = plan.request?.currentVersion
        automaticInstallAllowed = plan.request?.automaticInstallAllowed
    }
}
