import XCTest
@testable import MyVibeIslandCore

final class ScreenSelectionModelsTests: XCTestCase {
    func testScreenSelectionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ScreenSelectionMatrixFixture.self,
            from: try FixtureLoader.data("settings/screen-selection-matrix")
        )
        let coordinator = ScreenSelectionCoordinator()
        let notchScreens = [
            ScreenDescriptor(identifier: "external", displayName: "Studio Display", isBuiltIn: false, hasNotch: false, isMain: true),
            ScreenDescriptor(identifier: "built-in", displayName: "MacBook", isBuiltIn: true, hasNotch: true, isMain: false)
        ]
        let screens = sampleScreens()
        let manualSelected = coordinator.plan(
            .selectDisplay("side"),
            from: ScreenSelectionSnapshot(availableScreens: screens)
        )
        let followed = coordinator.plan(
            .focusDisplay("side"),
            from: ScreenSelectionSnapshot(
                mode: .followKeyboardFocus,
                availableScreens: screens,
                target: ScreenTarget(screen: screens[0])
            )
        )

        let cases = [
            ScreenSelectionCase(
                name: "built-in-notch-prefers-notched-display",
                plan: ScreenSelectionPlanProjection(coordinator.plan(
                    .refreshScreens(notchScreens),
                    from: ScreenSelectionSnapshot(mode: .builtInNotchDisplay)
                ))
            ),
            ScreenSelectionCase(
                name: "main-display-mode-selects-main",
                plan: ScreenSelectionPlanProjection(coordinator.plan(
                    .selectMode(.mainDisplay),
                    from: ScreenSelectionSnapshot(availableScreens: screens)
                ))
            ),
            ScreenSelectionCase(
                name: "follow-focus-known-display",
                plan: ScreenSelectionPlanProjection(followed)
            ),
            ScreenSelectionCase(
                name: "manual-display-survives-reconnect",
                plan: ScreenSelectionPlanProjection(coordinator.plan(
                    .refreshScreens([screens[1], screens[0]]),
                    from: manualSelected.nextSnapshot
                ))
            ),
            ScreenSelectionCase(
                name: "manual-display-falls-back-when-missing",
                plan: ScreenSelectionPlanProjection(coordinator.plan(
                    .refreshScreens([screens[0]]),
                    from: manualSelected.nextSnapshot
                ))
            ),
            ScreenSelectionCase(
                name: "dismiss-switch-tip-keeps-target",
                plan: ScreenSelectionPlanProjection(coordinator.plan(
                    .dismissSwitchTip,
                    from: ScreenSelectionSnapshot(
                        availableScreens: screens,
                        target: ScreenTarget(screen: screens[0]),
                        switchTipDismissed: false
                    )
                ))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testBuiltInNotchModePrefersNotchDisplayThenMainDisplay() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = [
            ScreenDescriptor(identifier: "external", displayName: "Studio Display", isBuiltIn: false, hasNotch: false, isMain: true),
            ScreenDescriptor(identifier: "built-in", displayName: "MacBook", isBuiltIn: true, hasNotch: true, isMain: false)
        ]

        let plan = coordinator.plan(.refreshScreens(screens), from: ScreenSelectionSnapshot(mode: .builtInNotchDisplay))

        XCTAssertEqual(plan.nextSnapshot.target?.identifier, "built-in")
        XCTAssertTrue(plan.targetDidChange)
    }

    func testMainDisplayModeSelectsMainDisplay() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = sampleScreens()

        let plan = coordinator.plan(.selectMode(.mainDisplay), from: ScreenSelectionSnapshot(availableScreens: screens))

        XCTAssertEqual(plan.nextSnapshot.mode, .mainDisplay)
        XCTAssertEqual(plan.nextSnapshot.target?.identifier, "main")
    }

    func testMainDisplayModeSelectsFirstOrderedScreenWhenMainDiffers() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = [sampleScreens()[1], sampleScreens()[0]]

        let plan = coordinator.plan(
            .selectMode(.mainDisplay),
            from: ScreenSelectionSnapshot(availableScreens: screens)
        )

        XCTAssertEqual(plan.nextSnapshot.target?.identifier, "side")
    }

    func testFollowFocusIgnoresUnknownFocusAndKeepsPreviousTarget() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = sampleScreens()
        let snapshot = ScreenSelectionSnapshot(mode: .followKeyboardFocus, availableScreens: screens, target: ScreenTarget(screen: screens[0]))

        let unknown = coordinator.plan(.focusDisplay("missing"), from: snapshot)
        XCTAssertEqual(unknown.nextSnapshot.target?.identifier, "main")
        XCTAssertFalse(unknown.targetDidChange)

        let known = coordinator.plan(.focusDisplay("side"), from: unknown.nextSnapshot)
        XCTAssertEqual(known.nextSnapshot.target?.identifier, "side")
        XCTAssertTrue(known.targetDidChange)
    }

    func testManualSelectionSurvivesReconnectAndFallsBackWhenMissing() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = sampleScreens()

        let selected = coordinator.plan(.selectDisplay("side"), from: ScreenSelectionSnapshot(availableScreens: screens))
        XCTAssertEqual(selected.nextSnapshot.mode, .manualDisplay)
        XCTAssertEqual(selected.nextSnapshot.manualScreenIdentifier, "side")
        XCTAssertEqual(selected.nextSnapshot.target?.identifier, "side")

        let reconnected = coordinator.plan(.refreshScreens([screens[1], screens[0]]), from: selected.nextSnapshot)
        XCTAssertEqual(reconnected.nextSnapshot.target?.identifier, "side")
        XCTAssertEqual(reconnected.nextSnapshot.manualScreenIdentifier, "side")

        let missing = coordinator.plan(.refreshScreens([screens[0]]), from: reconnected.nextSnapshot)
        XCTAssertEqual(missing.nextSnapshot.target?.identifier, "main")
        XCTAssertEqual(missing.nextSnapshot.manualScreenIdentifier, "side")
    }

    func testMissingManualSelectionFallsBackToFirstOrderedScreenBeforeMain() {
        let coordinator = ScreenSelectionCoordinator()
        let screens = [sampleScreens()[1], sampleScreens()[0]]
        let snapshot = ScreenSelectionSnapshot(
            mode: .manualDisplay,
            availableScreens: screens,
            manualScreenIdentifier: "missing"
        )

        let plan = coordinator.plan(.refreshScreens(screens), from: snapshot)

        XCTAssertEqual(plan.nextSnapshot.target?.identifier, "side")
    }

    func testDismissTipOnlyMutatesTipState() {
        let coordinator = ScreenSelectionCoordinator()
        let snapshot = ScreenSelectionSnapshot(availableScreens: sampleScreens(), switchTipDismissed: false)

        let plan = coordinator.plan(.dismissSwitchTip, from: snapshot)

        XCTAssertTrue(plan.nextSnapshot.switchTipDismissed)
        XCTAssertFalse(plan.targetDidChange)
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let screen = ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: true, isMain: true)
        let snapshot = ScreenSelectionSnapshot(
            mode: .manualDisplay,
            availableScreens: [screen],
            target: ScreenTarget(screen: screen),
            manualScreenIdentifier: "main",
            focusedScreenIdentifier: "main",
            switchTipDismissed: true
        )

        let decoded = try JSONDecoder().decode(
            ScreenSelectionSnapshot.self,
            from: try JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
    }

    private func sampleScreens() -> [ScreenDescriptor] {
        [
            ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: false, isMain: true),
            ScreenDescriptor(identifier: "side", displayName: "Side", isBuiltIn: false, hasNotch: false, isMain: false)
        ]
    }

    private struct ScreenSelectionMatrixFixture: Codable, Equatable {
        let cases: [ScreenSelectionCase]
    }

    private struct ScreenSelectionCase: Codable, Equatable {
        let name: String
        let plan: ScreenSelectionPlanProjection
    }

    private struct ScreenSelectionPlanProjection: Codable, Equatable {
        let nextSnapshot: ScreenSelectionSnapshot
        let targetDidChange: Bool

        init(_ plan: ScreenSelectionPlan) {
            self.nextSnapshot = plan.nextSnapshot
            self.targetDidChange = plan.targetDidChange
        }
    }
}
