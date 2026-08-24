import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitShortcutHintOverlayControllerTests: XCTestCase {
    @MainActor
    func testShortcutHintOverlayControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutHintOverlayControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/shortcut-hint-overlay-controller-matrix")
        )

        let actual = ShortcutHintOverlayControllerMatrixFixture(rows: [
            row(id: "present-hide-explicit-hide", initialSettings: Self.settings, actions: [.update(.command, true), .update(.option, true), .hide]),
            row(id: "disabled-then-enabled", initialSettings: Self.settings.withKeyboardShortcutsEnabled(false), actions: [.update(.command, true), .updateSettings(Self.settings)])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPresentsAndHidesShortcutHintsThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutHintOverlayController(
            settings: Self.settings,
            presentOverlay: { state in
                events.append("present:\(state.modifierKey.rawValue):\(state.items.map(\.displayText).joined(separator: ","))")
            },
            hideOverlay: {
                events.append("hide")
            }
        )

        let visible = controller.update(modifierKey: .command, isPanelExpanded: true)
        let hidden = controller.update(modifierKey: .option, isPanelExpanded: true)
        controller.hide()

        XCTAssertTrue(visible.isVisible)
        XCTAssertEqual(visible.items.map(\.action), [.approvePermission])
        XCTAssertFalse(hidden.isVisible)
        XCTAssertEqual(controller.state, ShortcutHintOverlayState(isVisible: false, modifierKey: .option))
        XCTAssertEqual(events, [
            "present:command:Cmd-Return",
            "hide",
            "hide"
        ])
    }

    @MainActor
    func testControllerUpdatesSettingsBeforeRecomputingHints() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutHintOverlayController(
            settings: Self.settings.withKeyboardShortcutsEnabled(false),
            presentOverlay: { state in
                events.append("present:\(state.items.map(\.title).joined(separator: ","))")
            },
            hideOverlay: {
                events.append("hide")
            }
        )

        let disabled = controller.update(modifierKey: .command, isPanelExpanded: true)
        let enabled = controller.updateSettings(Self.settings)

        XCTAssertFalse(disabled.isVisible)
        XCTAssertTrue(enabled.isVisible)
        XCTAssertEqual(controller.settings.keyboardShortcutsEnabled, true)
        XCTAssertEqual(events, [
            "hide",
            "present:Approve"
        ])
    }

    @MainActor
    func testControllerPublishesLastPresentationActionForComposition() {
        let controller = MyVibeIslandAppKitShortcutHintOverlayController(settings: Self.settings)

        let visible = controller.update(modifierKey: .command, isPanelExpanded: true)

        XCTAssertEqual(controller.lastPresentationAction, .present(visible))

        controller.hide()

        XCTAssertEqual(
            controller.lastPresentationAction,
            .hide(ShortcutHintOverlayState(isVisible: false, modifierKey: .command))
        )
    }

    private static let settings = ShortcutSettings(
        keyboardShortcutsEnabled: true,
        panelShortcuts: [
            HotKeyRegistrationSpec(
                id: "approve",
                action: .approvePermission,
                keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
                scope: .expandedPanel,
                isEnabled: true
            ),
            HotKeyRegistrationSpec(
                id: "collapse",
                action: .collapsePanel,
                keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                scope: .expandedPanel,
                isEnabled: true
            ),
        ]
    )

    @MainActor
    private func row(
        id: String,
        initialSettings: ShortcutSettings,
        actions: [ShortcutHintOverlayControllerFixtureAction]
    ) -> ShortcutHintOverlayControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutHintOverlayController(
            settings: initialSettings,
            presentOverlay: { events.append("present:\($0.modifierKey.rawValue):" + $0.items.map(\.displayText).joined(separator: ",")) },
            hideOverlay: { events.append("hide") }
        )
        var states: [ShortcutHintOverlayStateSummary] = []

        for action in actions {
            switch action {
            case let .update(modifierKey, expanded):
                states.append(ShortcutHintOverlayStateSummary(controller.update(modifierKey: modifierKey, isPanelExpanded: expanded)))
            case let .updateSettings(settings):
                states.append(ShortcutHintOverlayStateSummary(controller.updateSettings(settings)))
            case .hide:
                controller.hide()
                states.append(ShortcutHintOverlayStateSummary(controller.state))
            }
        }

        let lastAction: String?
        switch controller.lastPresentationAction {
        case .present: lastAction = "present"
        case .hide: lastAction = "hide"
        case nil: lastAction = nil
        }

        return ShortcutHintOverlayControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            states: states,
            finalState: ShortcutHintOverlayStateSummary(controller.state),
            keyboardShortcutsEnabled: controller.settings.keyboardShortcutsEnabled,
            lastAction: lastAction,
            events: events
        )
    }
}

private enum ShortcutHintOverlayControllerFixtureAction {
    case update(ModifierKeyOption, Bool)
    case updateSettings(ShortcutSettings)
    case hide

    var summary: String {
        switch self {
        case let .update(modifierKey, expanded): "update:\(modifierKey.rawValue):\(expanded)"
        case .updateSettings: "updateSettings"
        case .hide: "hide"
        }
    }
}

private struct ShortcutHintOverlayControllerMatrixFixture: Codable, Equatable {
    let rows: [ShortcutHintOverlayControllerMatrixRow]
}

private struct ShortcutHintOverlayControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let states: [ShortcutHintOverlayStateSummary]
    let finalState: ShortcutHintOverlayStateSummary
    let keyboardShortcutsEnabled: Bool
    let lastAction: String?
    let events: [String]
}

private struct ShortcutHintOverlayStateSummary: Codable, Equatable {
    let isVisible: Bool
    let modifierKey: String
    let itemTitles: [String]
    let displayTexts: [String]

    init(_ state: ShortcutHintOverlayState) {
        self.isVisible = state.isVisible
        self.modifierKey = state.modifierKey.rawValue
        self.itemTitles = state.items.map(\.title)
        self.displayTexts = state.items.map(\.displayText)
    }
}
