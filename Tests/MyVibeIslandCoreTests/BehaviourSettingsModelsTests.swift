import XCTest
@testable import MyVibeIslandCore

final class BehaviourSettingsModelsTests: XCTestCase {
    func testBehaviourSettingsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BehaviourSettingsMatrixFixture.self,
            from: try FixtureLoader.data("settings/behaviour-settings-matrix")
        )

        let actual = BehaviourSettingsMatrixFixture(rows: [
            BehaviourSettingsMatrixRow(
                id: "default",
                settings: BehaviourSettings()
            ),
            BehaviourSettingsMatrixRow(
                id: "custom",
                settings: BehaviourSettings(
                    showSubagents: true,
                    hoverToExpandEnabled: true,
                    hoverExpandDelay: 0.35,
                    autoCollapseOnMouseLeave: true,
                    transientRevealDwellSeconds: 4.5,
                    dismissTransientRevealOnOutsideClick: true,
                    autoExpandOnTaskComplete: true,
                    autoExpandOnAgentTeamComplete: true,
                    disableClickToJump: true
                )
            ),
            BehaviourSettingsMatrixRow(
                id: "clamped",
                settings: BehaviourSettings(
                    hoverExpandDelay: -1.0,
                    transientRevealDwellSeconds: 999.0
                )
            ),
            BehaviourSettingsMatrixRow(
                id: "automatic-reveals-disabled",
                settings: BehaviourSettings().withAutomaticRevealsEnabled(false)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testBehaviourSettingsRoundTripsDisplayAndInteractionPreferences() throws {
        let settings = BehaviourSettings(
            showSubagents: true,
            hoverToExpandEnabled: true,
            hoverExpandDelay: 0.35,
            autoCollapseOnMouseLeave: true,
            transientRevealDwellSeconds: 4.5,
            dismissTransientRevealOnOutsideClick: true,
            autoExpandOnTaskComplete: true,
            autoExpandOnAgentTeamComplete: true,
            disableClickToJump: true
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(BehaviourSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    func testDefaultBehaviourSettingsMatchNonIntrusiveInteractionDefaults() {
        let settings = BehaviourSettings()

        XCTAssertTrue(settings.showSubagents)
        XCTAssertTrue(settings.hoverToExpandEnabled)
        XCTAssertEqual(settings.hoverExpandDelay, 0.15)
        XCTAssertTrue(settings.autoCollapseOnMouseLeave)
        XCTAssertEqual(settings.mouseLeaveCollapseDelay, 0.25)
        XCTAssertEqual(settings.transientRevealDwellSeconds, 5.0)
        XCTAssertFalse(settings.dismissTransientRevealOnOutsideClick)
        XCTAssertTrue(settings.autoExpandOnTaskComplete)
        XCTAssertFalse(settings.autoExpandOnAgentTeamComplete)
        XCTAssertFalse(settings.disableClickToJump)
    }

    func testBehaviourSettingsClampTimingValues() {
        let settings = BehaviourSettings(
            hoverExpandDelay: -1.0,
            transientRevealDwellSeconds: 999.0
        )

        XCTAssertEqual(settings.hoverExpandDelay, 0.0)
        XCTAssertEqual(settings.transientRevealDwellSeconds, 30.0)
    }

    func testBehaviourSettingsCanDisableAutomaticRevealsWithoutChangingJumpPreference() {
        let settings = BehaviourSettings()
            .withAutomaticRevealsEnabled(false)

        XCTAssertFalse(settings.autoExpandOnTaskComplete)
        XCTAssertFalse(settings.autoExpandOnAgentTeamComplete)
        XCTAssertFalse(settings.disableClickToJump)
    }

    private struct BehaviourSettingsMatrixFixture: Codable, Equatable {
        let rows: [BehaviourSettingsMatrixRow]
    }

    private struct BehaviourSettingsMatrixRow: Codable, Equatable {
        let id: String
        let settings: BehaviourSettings
    }
}
