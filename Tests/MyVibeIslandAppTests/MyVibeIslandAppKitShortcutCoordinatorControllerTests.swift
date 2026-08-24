import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitShortcutCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testShortcutCoordinatorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/shortcut-coordinator-controller-matrix")
        )

        let actual = ShortcutCoordinatorControllerMatrixFixture(rows: [
            row(id: "start-dispatch-stop", actions: [.start, .hotKey("toggle-island"), .stop]),
            row(id: "expand-then-disable", actions: [.start, .enterScope(.expandedPanel), .disableSettings])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRegistersDispatchesAndUnregistersShortcutsThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutCoordinatorController(
            settings: Self.settings,
            registerShortcuts: { plan in
                events.append("register:\(plan.registrations.map(\.id).joined(separator: ","))")
            },
            unregisterShortcuts: { ids in
                events.append("unregister:\(ids.joined(separator: ","))")
            },
            routeShortcutAction: { action in
                events.append("route:\(action.rawValue)")
            }
        )

        let started = controller.start()
        let dispatch = controller.handleHotKey("toggle-island")
        let stopped = controller.stop()

        XCTAssertEqual(started.action, .registerShortcuts)
        XCTAssertEqual(dispatch.action, .dispatchAction)
        XCTAssertEqual(stopped.action, .unregisterShortcuts)
        XCTAssertFalse(controller.state.isStarted)
        XCTAssertEqual(events, [
            "register:toggle-island",
            "route:toggleIsland",
            "unregister:toggle-island"
        ])
    }

    @MainActor
    func testControllerUpdatesSettingsAndScopeRegistrations() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutCoordinatorController(
            settings: Self.settings,
            registerShortcuts: { plan in
                events.append("register:\(plan.registrations.map(\.id).joined(separator: ","))")
            },
            unregisterShortcuts: { ids in
                events.append("unregister:\(ids.joined(separator: ","))")
            },
            routeShortcutAction: { _ in }
        )

        _ = controller.start()
        let expanded = controller.enterScope(.expandedPanel)
        let disabled = controller.updateSettings(Self.settings.withKeyboardShortcutsEnabled(false))

        XCTAssertEqual(expanded.registrationPlan.registrations.map(\.id), ["toggle-island", "collapse"])
        XCTAssertEqual(disabled.hotKeyIdsToUnregister, ["collapse", "toggle-island"])
        XCTAssertEqual(controller.settings.keyboardShortcutsEnabled, false)
        XCTAssertEqual(events, [
            "register:toggle-island",
            "register:toggle-island,collapse",
            "unregister:collapse,toggle-island"
        ])
    }

    @MainActor
    func testControllerPublishesLastShortcutLifecyclePlanForOrchestration() {
        let controller = MyVibeIslandAppKitShortcutCoordinatorController(
            settings: Self.settings,
            registerShortcuts: { _ in },
            unregisterShortcuts: { _ in },
            routeShortcutAction: { _ in }
        )

        _ = controller.start()

        XCTAssertEqual(controller.lastLifecyclePlan?.action, .registerShortcuts)
        XCTAssertEqual(controller.lastLifecyclePlan?.registrationPlan.registrations.map(\.id), ["toggle-island"])
    }

    @MainActor
    func testControllerRoutesInjectedModifierReleaseEvent() {
        var released = false
        let controller = MyVibeIslandAppKitShortcutCoordinatorController(
            onModifierRelease: { released = true }
        )

        controller.handleModifierReleaseEvent()

        XCTAssertTrue(released)
    }

    private static let settings = ShortcutSettings(
        globalShortcuts: [
            HotKeyRegistrationSpec(
                id: "toggle-island",
                action: .toggleIsland,
                keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .option]),
                scope: .persistentGlobal,
                isEnabled: true
            ),
        ],
        panelShortcuts: [
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
        actions: [ShortcutCoordinatorControllerFixtureAction]
    ) -> ShortcutCoordinatorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutCoordinatorController(
            settings: Self.settings,
            registerShortcuts: { events.append("register:" + $0.registrations.map(\.id).joined(separator: ",")) },
            unregisterShortcuts: { events.append("unregister:" + $0.joined(separator: ",")) },
            routeShortcutAction: { events.append("route:\($0.rawValue)") }
        )
        var outcomes: [String] = []

        for action in actions {
            switch action {
            case .start: outcomes.append("lifecycle:\(controller.start().action.rawValue)")
            case .stop: outcomes.append("lifecycle:\(controller.stop().action.rawValue)")
            case let .enterScope(scope): outcomes.append("lifecycle:\(controller.enterScope(scope).action.rawValue)")
            case let .hotKey(id):
                let plan = controller.handleHotKey(id)
                outcomes.append("dispatch:\(plan.action.rawValue):\(plan.shortcutAction?.rawValue ?? "none")")
            case .disableSettings:
                outcomes.append("lifecycle:\(controller.updateSettings(Self.settings.withKeyboardShortcutsEnabled(false)).action.rawValue)")
            }
        }

        return ShortcutCoordinatorControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            outcomes: outcomes,
            state: ShortcutCoordinatorStateSummary(controller.state),
            keyboardShortcutsEnabled: controller.settings.keyboardShortcutsEnabled,
            lastLifecycleAction: controller.lastLifecyclePlan?.action.rawValue,
            events: events
        )
    }
}

private enum ShortcutCoordinatorControllerFixtureAction {
    case start
    case stop
    case enterScope(ShortcutScope)
    case hotKey(String)
    case disableSettings

    var summary: String {
        switch self {
        case .start: "start"
        case .stop: "stop"
        case let .enterScope(scope): "enterScope:\(scope.rawValue)"
        case let .hotKey(id): "hotKey:\(id)"
        case .disableSettings: "disableSettings"
        }
    }
}

private struct ShortcutCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [ShortcutCoordinatorControllerMatrixRow]
}

private struct ShortcutCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let outcomes: [String]
    let state: ShortcutCoordinatorStateSummary
    let keyboardShortcutsEnabled: Bool
    let lastLifecycleAction: String?
    let events: [String]
}

private struct ShortcutCoordinatorStateSummary: Codable, Equatable {
    let activeScopes: [String]
    let registeredHotKeyIds: [String]
    let isStarted: Bool

    init(_ state: ShortcutCoordinatorState) {
        self.activeScopes = state.activeScopes.map(\.rawValue)
        self.registeredHotKeyIds = state.registeredHotKeyIds
        self.isStarted = state.isStarted
    }
}
