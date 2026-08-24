import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitShortcutManagerControllerTests: XCTestCase {
    @MainActor
    func testShortcutManagerControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutManagerControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/shortcut-manager-controller-matrix")
        )

        let actual = ShortcutManagerControllerMatrixFixture(rows: [
            row(id: "start-dispatch-stop", rejectedIds: [], actions: [.start, .hotKey("toggle-island"), .stop]),
            row(id: "registration-rejected", rejectedIds: ["toggle-island"], actions: [.start, .hotKey("toggle-island")]),
            row(id: "scope-enter-exit", rejectedIds: [], actions: [.start, .enterScope(.expandedPanel), .exitScope(.expandedPanel)])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testManagerStartsRegistersRoutesAndStopsShortcutsThroughCarbonBridge() {
        var events: [String] = []
        let manager = MyVibeIslandAppKitShortcutManagerController(
            settings: Self.settings,
            registerHotKey: { ref in
                events.append("register:\(ref.id):\(ref.carbonId)")
                return true
            },
            unregisterHotKey: { ref in
                events.append("unregister:\(ref.id):\(ref.carbonId)")
            },
            routeShortcutAction: { action in
                events.append("route:\(action.rawValue)")
            }
        )

        let started = manager.start()
        let dispatched = manager.handleHotKey("toggle-island")
        let stopped = manager.stop()

        XCTAssertEqual(started.action, .registerShortcuts)
        XCTAssertEqual(dispatched.action, .dispatchAction)
        XCTAssertEqual(stopped.action, .unregisterShortcuts)
        XCTAssertEqual(manager.carbonRefs.map(\.id), [])
        XCTAssertEqual(events, [
            "register:toggle-island:1",
            "route:toggleIsland",
            "unregister:toggle-island:1"
        ])
    }

    @MainActor
    func testManagerTracksCarbonRegistrationFailuresWithoutRoutingRejectedHotKey() {
        var events: [String] = []
        let manager = MyVibeIslandAppKitShortcutManagerController(
            settings: Self.settings,
            registerHotKey: { ref in
                events.append("register:\(ref.id)")
                return ref.id != "toggle-island"
            },
            unregisterHotKey: { ref in
                events.append("unregister:\(ref.id)")
            },
            routeShortcutAction: { action in
                events.append("route:\(action.rawValue)")
            }
        )

        _ = manager.start()
        let dispatch = manager.handleHotKey("toggle-island")

        XCTAssertEqual(manager.lastCarbonRegistrationPlan?.registeredHotKeys, [])
        XCTAssertEqual(manager.lastCarbonRegistrationPlan?.failures, [
            CarbonHotKeyRegistrationFailure(specId: "toggle-island", reason: .registrationRejected),
        ])
        XCTAssertEqual(dispatch.action, .ignore)
        XCTAssertEqual(events, ["register:toggle-island"])
    }

    @MainActor
    func testManagerRegistersScopeShortcutsAndUnregistersThemOnScopeExit() {
        var events: [String] = []
        let manager = MyVibeIslandAppKitShortcutManagerController(
            settings: Self.settings,
            registerHotKey: { ref in
                events.append("register:\(ref.id)")
                return true
            },
            unregisterHotKey: { ref in
                events.append("unregister:\(ref.id)")
            },
            routeShortcutAction: { _ in }
        )

        _ = manager.start()
        let expanded = manager.enterScope(.expandedPanel)
        let collapsed = manager.exitScope(.expandedPanel)

        XCTAssertEqual(expanded.registrationPlan.registrations.map(\.id), ["toggle-island", "collapse"])
        XCTAssertEqual(collapsed.hotKeyIdsToUnregister, ["collapse"])
        XCTAssertEqual(manager.carbonRefs.map(\.id), ["toggle-island"])
        XCTAssertEqual(events, [
            "register:toggle-island",
            "register:collapse",
            "unregister:collapse"
        ])
    }

    private static let settings = ShortcutSettings(
        globalShortcuts: [
            HotKeyRegistrationSpec(
                id: "toggle-island",
                action: .toggleIsland,
                keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .option]),
                scope: .persistentGlobal
            ),
        ],
        panelShortcuts: [
            HotKeyRegistrationSpec(
                id: "collapse",
                action: .collapsePanel,
                keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                scope: .expandedPanel
            ),
        ]
    )

    @MainActor
    private func row(
        id: String,
        rejectedIds: Set<String>,
        actions: [ShortcutManagerControllerFixtureAction]
    ) -> ShortcutManagerControllerMatrixRow {
        var events: [String] = []
        let manager = MyVibeIslandAppKitShortcutManagerController(
            settings: Self.settings,
            registerHotKey: {
                events.append("register:\($0.id):\($0.carbonId)")
                return !rejectedIds.contains($0.id)
            },
            unregisterHotKey: { events.append("unregister:\($0.id):\($0.carbonId)") },
            routeShortcutAction: { events.append("route:\($0.rawValue)") }
        )
        var outcomes: [String] = []

        for action in actions {
            switch action {
            case .start: outcomes.append("lifecycle:\(manager.start().action.rawValue)")
            case .stop: outcomes.append("lifecycle:\(manager.stop().action.rawValue)")
            case let .enterScope(scope): outcomes.append("lifecycle:\(manager.enterScope(scope).action.rawValue)")
            case let .exitScope(scope): outcomes.append("lifecycle:\(manager.exitScope(scope).action.rawValue)")
            case let .hotKey(id): outcomes.append("dispatch:\(manager.handleHotKey(id).action.rawValue)")
            }
        }

        return ShortcutManagerControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            outcomes: outcomes,
            state: ShortcutCoordinatorStateSummaryForManager(manager.coordinatorState),
            carbonRefIds: manager.carbonRefs.map(\.id),
            registeredIds: manager.lastCarbonRegistrationPlan?.registeredHotKeys.map(\.id),
            registrationFailures: manager.lastCarbonRegistrationPlan?.failures.map { "\($0.specId):\($0.reason.rawValue)" },
            removedIds: manager.lastCarbonUnregistrationPlan?.removedHotKeyIds,
            events: events
        )
    }
}

private enum ShortcutManagerControllerFixtureAction {
    case start
    case stop
    case enterScope(ShortcutScope)
    case exitScope(ShortcutScope)
    case hotKey(String)

    var summary: String {
        switch self {
        case .start: "start"
        case .stop: "stop"
        case let .enterScope(scope): "enterScope:\(scope.rawValue)"
        case let .exitScope(scope): "exitScope:\(scope.rawValue)"
        case let .hotKey(id): "hotKey:\(id)"
        }
    }
}

private struct ShortcutManagerControllerMatrixFixture: Codable, Equatable {
    let rows: [ShortcutManagerControllerMatrixRow]
}

private struct ShortcutManagerControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let outcomes: [String]
    let state: ShortcutCoordinatorStateSummaryForManager
    let carbonRefIds: [String]
    let registeredIds: [String]?
    let registrationFailures: [String]?
    let removedIds: [String]?
    let events: [String]
}

private struct ShortcutCoordinatorStateSummaryForManager: Codable, Equatable {
    let activeScopes: [String]
    let registeredHotKeyIds: [String]
    let isStarted: Bool

    init(_ state: ShortcutCoordinatorState) {
        self.activeScopes = state.activeScopes.map(\.rawValue)
        self.registeredHotKeyIds = state.registeredHotKeyIds
        self.isStarted = state.isStarted
    }
}
