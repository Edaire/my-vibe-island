import XCTest
@testable import MyVibeIslandCore

final class ShortcutRuntimeStateModelsTests: XCTestCase {
    func testShortcutRuntimeStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutRuntimeStateMatrixFixture.self,
            from: try FixtureLoader.data("settings/shortcut-runtime-state-matrix")
        )

        let model = ShortcutRuntimeModel()
        let actual = ShortcutRuntimeStateMatrixFixture(
            states: [
                stateRow(id: "default", state: ShortcutRuntimeState()),
                stateRow(
                    id: "normalized-negative-times",
                    state: ShortcutRuntimeState(
                        lastFiredAtMilliseconds: ["toggle-island": -50],
                        dedupWindowMilliseconds: -1,
                        switcherOpenedAtMilliseconds: -100,
                        modifierHoldThresholdMilliseconds: -10,
                        modifierKey: .control
                    )
                ),
                stateRow(
                    id: "held-reverse-switcher",
                    state: ShortcutRuntimeState(
                        lastFiredAtMilliseconds: ["toggle-island": 1_000],
                        switcherHasNavigated: true,
                        switcherOpenedAtMilliseconds: 900,
                        isModifierHeld: true,
                        modifierKey: .option,
                        reverseSwitcherEnabled: true
                    )
                ),
            ],
            hotKeyPlans: [
                hotKeyRow(
                    id: "suppressed-within-window",
                    hotKeyId: "toggle-island",
                    atMilliseconds: 1_100,
                    state: ShortcutRuntimeState(
                        lastFiredAtMilliseconds: ["toggle-island": 1_000],
                        dedupWindowMilliseconds: 250
                    ),
                    model: model
                ),
                hotKeyRow(
                    id: "dispatch-after-window",
                    hotKeyId: "toggle-island",
                    atMilliseconds: 1_300,
                    state: ShortcutRuntimeState(
                        lastFiredAtMilliseconds: ["toggle-island": 1_000],
                        dedupWindowMilliseconds: 250
                    ),
                    model: model
                ),
                hotKeyRow(
                    id: "dispatch-normalizes-negative-time",
                    hotKeyId: "focus-active",
                    atMilliseconds: -5,
                    state: ShortcutRuntimeState(),
                    model: model
                ),
            ],
            modifierPlans: [
                modifierRow(
                    id: "keep-waiting-before-threshold",
                    modifierKey: .control,
                    heldForMilliseconds: 250,
                    atMilliseconds: 2_000,
                    state: ShortcutRuntimeState(
                        modifierHoldThresholdMilliseconds: 300,
                        modifierKey: .control
                    ),
                    model: model
                ),
                modifierRow(
                    id: "open-switcher-at-threshold",
                    modifierKey: .control,
                    heldForMilliseconds: 300,
                    atMilliseconds: 2_000,
                    state: ShortcutRuntimeState(
                        switcherHasNavigated: true,
                        modifierHoldThresholdMilliseconds: 300,
                        modifierKey: .control
                    ),
                    model: model
                ),
                modifierRow(
                    id: "open-switcher-normalizes-negative-time",
                    modifierKey: .option,
                    heldForMilliseconds: 400,
                    atMilliseconds: -20,
                    state: ShortcutRuntimeState(modifierHoldThresholdMilliseconds: 300),
                    model: model
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testShortcutRuntimeStateRoundTripsObservedSwitcherAndDedupFields() throws {
        let state = ShortcutRuntimeState(
            lastFiredAtMilliseconds: ["toggle-island": 1_000],
            dedupWindowMilliseconds: 250,
            switcherHasNavigated: true,
            switcherOpenedAtMilliseconds: 900,
            modifierHoldThresholdMilliseconds: 300,
            isModifierHeld: true,
            modifierKey: .control,
            reverseSwitcherEnabled: true
        )

        let decoded = try JSONDecoder().decode(
            ShortcutRuntimeState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.modifierKey, .control)
        XCTAssertEqual(decoded.dedupWindowMilliseconds, 250)
    }

    func testShortcutRuntimeModelDeduplicatesHotKeyDispatchesWithinWindow() {
        let model = ShortcutRuntimeModel()
        let state = ShortcutRuntimeState(
            lastFiredAtMilliseconds: ["toggle-island": 1_000],
            dedupWindowMilliseconds: 250
        )

        let suppressed = model.planHotKeyDispatch(
            hotKeyId: "toggle-island",
            atMilliseconds: 1_100,
            state: state
        )
        let dispatched = model.planHotKeyDispatch(
            hotKeyId: "toggle-island",
            atMilliseconds: 1_300,
            state: state
        )

        XCTAssertEqual(suppressed.decision, .suppressedDuplicate)
        XCTAssertEqual(suppressed.nextState.lastFiredAtMilliseconds["toggle-island"], 1_000)
        XCTAssertEqual(dispatched.decision, .dispatch)
        XCTAssertEqual(dispatched.nextState.lastFiredAtMilliseconds["toggle-island"], 1_300)
    }

    func testShortcutRuntimeModelOpensSwitcherAfterModifierHoldThreshold() {
        let model = ShortcutRuntimeModel()
        let state = ShortcutRuntimeState(
            modifierHoldThresholdMilliseconds: 300,
            isModifierHeld: false,
            modifierKey: .control
        )

        let held = model.planModifierHold(
            modifierKey: .control,
            heldForMilliseconds: 350,
            atMilliseconds: 2_000,
            state: state
        )

        XCTAssertEqual(held.decision, .openSwitcher)
        XCTAssertTrue(held.nextState.isModifierHeld)
        XCTAssertEqual(held.nextState.switcherOpenedAtMilliseconds, 2_000)
        XCTAssertFalse(held.nextState.switcherHasNavigated)
    }

    private func stateRow(id: String, state: ShortcutRuntimeState) -> ShortcutRuntimeStateRowFixture {
        ShortcutRuntimeStateRowFixture(id: id, state: state.fixture)
    }

    private func hotKeyRow(
        id: String,
        hotKeyId: String,
        atMilliseconds: Int,
        state: ShortcutRuntimeState,
        model: ShortcutRuntimeModel
    ) -> ShortcutRuntimeHotKeyRowFixture {
        let plan = model.planHotKeyDispatch(
            hotKeyId: hotKeyId,
            atMilliseconds: atMilliseconds,
            state: state
        )
        return ShortcutRuntimeHotKeyRowFixture(
            id: id,
            hotKeyId: plan.hotKeyId,
            decision: plan.decision.rawValue,
            nextState: plan.nextState.fixture
        )
    }

    private func modifierRow(
        id: String,
        modifierKey: ModifierKeyOption,
        heldForMilliseconds: Int,
        atMilliseconds: Int,
        state: ShortcutRuntimeState,
        model: ShortcutRuntimeModel
    ) -> ShortcutRuntimeModifierRowFixture {
        let plan = model.planModifierHold(
            modifierKey: modifierKey,
            heldForMilliseconds: heldForMilliseconds,
            atMilliseconds: atMilliseconds,
            state: state
        )
        return ShortcutRuntimeModifierRowFixture(
            id: id,
            modifierKey: plan.modifierKey.rawValue,
            decision: plan.decision.rawValue,
            nextState: plan.nextState.fixture
        )
    }

    fileprivate struct ShortcutRuntimeStateMatrixFixture: Codable, Equatable {
        let states: [ShortcutRuntimeStateRowFixture]
        let hotKeyPlans: [ShortcutRuntimeHotKeyRowFixture]
        let modifierPlans: [ShortcutRuntimeModifierRowFixture]
    }

    fileprivate struct ShortcutRuntimeStateRowFixture: Codable, Equatable {
        let id: String
        let state: ShortcutRuntimeStateFixture
    }

    fileprivate struct ShortcutRuntimeHotKeyRowFixture: Codable, Equatable {
        let id: String
        let hotKeyId: String
        let decision: String
        let nextState: ShortcutRuntimeStateFixture
    }

    fileprivate struct ShortcutRuntimeModifierRowFixture: Codable, Equatable {
        let id: String
        let modifierKey: String
        let decision: String
        let nextState: ShortcutRuntimeStateFixture
    }

    fileprivate struct ShortcutRuntimeStateFixture: Codable, Equatable {
        let lastFiredAtMilliseconds: [String: Int]
        let dedupWindowMilliseconds: Int
        let switcherHasNavigated: Bool
        let switcherOpenedAtMilliseconds: Int?
        let modifierHoldThresholdMilliseconds: Int
        let isModifierHeld: Bool
        let modifierKey: String?
        let reverseSwitcherEnabled: Bool
    }
}

private extension ShortcutRuntimeState {
    var fixture: ShortcutRuntimeStateModelsTests.ShortcutRuntimeStateFixture {
        ShortcutRuntimeStateModelsTests.ShortcutRuntimeStateFixture(
            lastFiredAtMilliseconds: lastFiredAtMilliseconds,
            dedupWindowMilliseconds: dedupWindowMilliseconds,
            switcherHasNavigated: switcherHasNavigated,
            switcherOpenedAtMilliseconds: switcherOpenedAtMilliseconds,
            modifierHoldThresholdMilliseconds: modifierHoldThresholdMilliseconds,
            isModifierHeld: isModifierHeld,
            modifierKey: modifierKey?.rawValue,
            reverseSwitcherEnabled: reverseSwitcherEnabled
        )
    }
}
