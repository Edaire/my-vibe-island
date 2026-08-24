import XCTest
@testable import MyVibeIslandCore

final class ShortcutCoordinatorPlanModelsTests: XCTestCase {
    func testShortcutCoordinatorPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutCoordinatorPlanMatrixFixture.self,
            from: try FixtureLoader.data("settings/shortcut-coordinator-plan-matrix")
        )

        let coordinator = ShortcutCoordinator(settings: Self.settings)
        let startedExpanded = ShortcutCoordinatorState(
            activeScopes: [.persistentGlobal, .expandedPanel],
            registeredHotKeyIds: ["toggle-island", "collapse"],
            isStarted: true
        )

        let actual = ShortcutCoordinatorPlanMatrixFixture(
            lifecycleRows: [
                lifecycleRow(
                    id: "start-registers-persistent",
                    plan: coordinator.plan(.start, from: ShortcutCoordinatorState())
                ),
                lifecycleRow(
                    id: "enter-expanded-registers-panel",
                    plan: coordinator.plan(
                        .enterScope(.expandedPanel),
                        from: ShortcutCoordinatorState(
                            activeScopes: [.persistentGlobal],
                            registeredHotKeyIds: ["toggle-island"],
                            isStarted: true
                        )
                    )
                ),
                lifecycleRow(
                    id: "exit-expanded-unregisters-panel",
                    plan: coordinator.plan(.exitScope(.expandedPanel), from: startedExpanded)
                ),
                lifecycleRow(
                    id: "disable-settings-unregisters-all",
                    plan: coordinator.plan(
                        .updateSettings(Self.settings.withKeyboardShortcutsEnabled(false)),
                        from: startedExpanded
                    )
                ),
                lifecycleRow(
                    id: "stop-unregisters-all-and-clears-started",
                    plan: coordinator.plan(.stop, from: startedExpanded)
                ),
            ],
            dispatchRows: [
                dispatchRow(
                    id: "registered-global-dispatches",
                    plan: coordinator.planDispatch(
                        hotKeyId: "toggle-island",
                        state: ShortcutCoordinatorState(
                            activeScopes: [.persistentGlobal],
                            registeredHotKeyIds: ["toggle-island"],
                            isStarted: true
                        )
                    )
                ),
                dispatchRow(
                    id: "unregistered-known-hotkey-ignored",
                    plan: coordinator.planDispatch(
                        hotKeyId: "collapse",
                        state: ShortcutCoordinatorState(
                            activeScopes: [.persistentGlobal],
                            registeredHotKeyIds: ["toggle-island"],
                            isStarted: true
                        )
                    )
                ),
                dispatchRow(
                    id: "registered-unknown-hotkey-ignored",
                    plan: coordinator.planDispatch(
                        hotKeyId: "unknown",
                        state: ShortcutCoordinatorState(
                            activeScopes: [.persistentGlobal],
                            registeredHotKeyIds: ["unknown"],
                            isStarted: true
                        )
                    )
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testShortcutCoordinatorStateRoundTripsActiveScopesAndRegistrations() throws {
        let state = ShortcutCoordinatorState(
            activeScopes: [.persistentGlobal, .expandedPanel],
            registeredHotKeyIds: ["toggle-island", "collapse"],
            isStarted: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShortcutCoordinatorState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.activeScopes, [.persistentGlobal, .expandedPanel])
    }

    func testShortcutCoordinatorPlansStartAndScopeEntryRegistrations() {
        let coordinator = ShortcutCoordinator(settings: Self.settings)

        let startPlan = coordinator.plan(.start, from: ShortcutCoordinatorState())
        let expandedPlan = coordinator.plan(.enterScope(.expandedPanel), from: startPlan.nextState)

        XCTAssertEqual(startPlan.action, .registerShortcuts)
        XCTAssertEqual(startPlan.registrationPlan.registrations.map(\.id), ["toggle-island"])
        XCTAssertEqual(startPlan.nextState.activeScopes, [.persistentGlobal])
        XCTAssertEqual(startPlan.nextState.registeredHotKeyIds, ["toggle-island"])

        XCTAssertEqual(expandedPlan.registrationPlan.registrations.map(\.id), ["toggle-island", "collapse"])
        XCTAssertEqual(expandedPlan.nextState.activeScopes, [.persistentGlobal, .expandedPanel])
        XCTAssertEqual(expandedPlan.nextState.registeredHotKeyIds, ["toggle-island", "collapse"])
    }

    func testShortcutCoordinatorPlansDisableAndScopeExitUnregistrationWithoutClearingMappings() {
        let coordinator = ShortcutCoordinator(settings: Self.settings)
        let started = ShortcutCoordinatorState(
            activeScopes: [.persistentGlobal, .expandedPanel],
            registeredHotKeyIds: ["toggle-island", "collapse"],
            isStarted: true
        )

        let exitPlan = coordinator.plan(.exitScope(.expandedPanel), from: started)
        let disablePlan = coordinator.plan(.updateSettings(Self.settings.withKeyboardShortcutsEnabled(false)), from: started)

        XCTAssertEqual(exitPlan.action, .unregisterShortcuts)
        XCTAssertEqual(exitPlan.hotKeyIdsToUnregister, ["collapse"])
        XCTAssertEqual(exitPlan.nextState.activeScopes, [.persistentGlobal])
        XCTAssertEqual(exitPlan.nextState.registeredHotKeyIds, ["toggle-island"])

        XCTAssertEqual(disablePlan.action, .unregisterShortcuts)
        XCTAssertEqual(disablePlan.hotKeyIdsToUnregister, ["collapse", "toggle-island"])
        XCTAssertTrue(disablePlan.nextState.registeredHotKeyIds.isEmpty)
        XCTAssertEqual(coordinator.settings.globalShortcuts.map(\.id), ["toggle-island"])
    }

    func testShortcutCoordinatorPlansDispatchWithoutBypassingPolicy() {
        let coordinator = ShortcutCoordinator(settings: Self.settings)

        let dispatchPlan = coordinator.planDispatch(
            hotKeyId: "toggle-island",
            state: ShortcutCoordinatorState(
                activeScopes: [.persistentGlobal],
                registeredHotKeyIds: ["toggle-island"],
                isStarted: true
            )
        )
        let unregisteredPlan = coordinator.planDispatch(
            hotKeyId: "collapse",
            state: ShortcutCoordinatorState(activeScopes: [.persistentGlobal], registeredHotKeyIds: [], isStarted: true)
        )

        XCTAssertEqual(dispatchPlan.action, .dispatchAction)
        XCTAssertEqual(dispatchPlan.shortcutAction, .toggleIsland)
        XCTAssertEqual(dispatchPlan.dispatchPolicy, .routeThroughActionRouter)
        XCTAssertEqual(unregisteredPlan.action, .ignore)
        XCTAssertEqual(unregisteredPlan.dispatchPolicy, .notRegistered)
    }

    private static let settings = ShortcutSettings(
        globalShortcuts: [
            HotKeyRegistrationSpec(
                id: "toggle-island",
                action: .toggleIsland,
                keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .option]),
                scope: .persistentGlobal,
                isEnabled: true
            ),
        ],
        panelShortcuts: [
            HotKeyRegistrationSpec(
                id: "collapse",
                action: .collapsePanel,
                keyCombo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                scope: .expandedPanel,
                isEnabled: true
            ),
        ]
    )

    private func lifecycleRow(
        id: String,
        plan: ShortcutCoordinatorLifecyclePlan
    ) -> ShortcutCoordinatorLifecycleRow {
        ShortcutCoordinatorLifecycleRow(
            id: id,
            action: plan.action.rawValue,
            registrationIds: plan.registrationPlan.registrations.map(\.id),
            skipped: plan.registrationPlan.skipped.map {
                ShortcutCoordinatorSkippedFixture(specId: $0.specId, reason: $0.reason.rawValue)
            },
            conflictIds: plan.registrationPlan.conflicts.map(\.specId),
            hotKeyIdsToUnregister: plan.hotKeyIdsToUnregister,
            nextState: plan.nextState.fixture
        )
    }

    private func dispatchRow(
        id: String,
        plan: ShortcutDispatchPlan
    ) -> ShortcutCoordinatorDispatchRow {
        ShortcutCoordinatorDispatchRow(
            id: id,
            action: plan.action.rawValue,
            hotKeyId: plan.hotKeyId,
            shortcutAction: plan.shortcutAction?.rawValue,
            dispatchPolicy: plan.dispatchPolicy.rawValue
        )
    }

    private struct ShortcutCoordinatorPlanMatrixFixture: Codable, Equatable {
        let lifecycleRows: [ShortcutCoordinatorLifecycleRow]
        let dispatchRows: [ShortcutCoordinatorDispatchRow]
    }

    private struct ShortcutCoordinatorLifecycleRow: Codable, Equatable {
        let id: String
        let action: String
        let registrationIds: [String]
        let skipped: [ShortcutCoordinatorSkippedFixture]
        let conflictIds: [String]
        let hotKeyIdsToUnregister: [String]
        let nextState: ShortcutCoordinatorStateFixture
    }

    private struct ShortcutCoordinatorSkippedFixture: Codable, Equatable {
        let specId: String
        let reason: String
    }

    private struct ShortcutCoordinatorDispatchRow: Codable, Equatable {
        let id: String
        let action: String
        let hotKeyId: String
        let shortcutAction: String?
        let dispatchPolicy: String
    }

    fileprivate struct ShortcutCoordinatorStateFixture: Codable, Equatable {
        let activeScopes: [String]
        let registeredHotKeyIds: [String]
        let isStarted: Bool
    }
}

private extension ShortcutCoordinatorState {
    var fixture: ShortcutCoordinatorPlanModelsTests.ShortcutCoordinatorStateFixture {
        ShortcutCoordinatorPlanModelsTests.ShortcutCoordinatorStateFixture(
            activeScopes: activeScopes.map(\.rawValue),
            registeredHotKeyIds: registeredHotKeyIds,
            isStarted: isStarted
        )
    }
}
