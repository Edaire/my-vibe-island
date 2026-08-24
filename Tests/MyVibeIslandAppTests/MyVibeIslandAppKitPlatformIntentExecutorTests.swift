import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitPlatformIntentExecutorTests: XCTestCase {
    @MainActor
    func testPlatformIntentExecutorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            PlatformIntentExecutorMatrixFixture.self,
            from: try AppFixtureLoader.data("app/platform-intent-executor-matrix")
        )

        let actual = PlatformIntentExecutorMatrixFixture(rows: [
            executeRow(
                id: "lifecycle-route-and-overlay",
                intents: [
                    .lifecycle(.createRuntime),
                    .showIsland,
                    .openSettings(SettingsDeepLink(section: .integrations, rowId: "codex")),
                    .showOnboarding,
                    .overlay(.routeAction(.openSettings)),
                    .ignoredMenuCommand(.quit),
                    .quitApplication
                ]
            ),
            executeRow(
                id: "runtime-and-notch-window",
                intents: [
                    .startRuntimeOwner(.bridgeServer),
                    .startRuntimeOwner(.sessionCoordinator),
                    .stopRuntimeOwner(.bridgeServer),
                    .createNotchPanel,
                    .installNotchEventMonitors,
                    .applyTargetScreen("built-in"),
                    .applyNotchPlacement(DisplayPlacementPlan(
                        closedFrame: DisplayFrame(x: 10, y: 20, width: 180, height: 40),
                        expandedFrame: DisplayFrame(x: 0, y: 0, width: 420, height: 320),
                        anchor: DisplayPoint(x: 100, y: 20),
                        safeAreaAdjustment: 0
                    )),
                    .showNotchPanel,
                    .hideNotchPanel,
                    .removeNotchEventMonitors,
                    .closeNotchPanel
                ]
            ),
            executeRow(
                id: "menu-preferences-and-maintenance",
                intents: [
                    .applyStatusItemMenu(Self.singleCommandMenuSnapshot),
                    .setDockIconVisible(true),
                    .setLaunchAtLoginEnabled(false),
                    .checkForUpdates,
                    .exportDiagnostics
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testExecutorAppliesStatusItemMenuIntent() {
        var appliedSnapshots: [StatusItemMenuSnapshot] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            applyStatusItemMenu: { snapshot in
                appliedSnapshots.append(snapshot)
            }
        )
        let snapshot = StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            entries: [
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Open Settings",
                    command: .openSettings,
                    isEnabled: true
                )
            ]
        )

        let result = executor.execute([
            .applyStatusItemMenu(snapshot)
        ])

        XCTAssertEqual(result.executedIntents, [.applyStatusItemMenu(snapshot)])
        XCTAssertEqual(appliedSnapshots, [snapshot])
    }

    @MainActor
    func testExecutorAppliesNotchPanelWindowIntentsInOrder() {
        var events: [String] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            createNotchPanel: {
                events.append("create")
            },
            installNotchEventMonitors: {
                events.append("install-monitors")
            },
            removeNotchEventMonitors: {
                events.append("remove-monitors")
            },
            applyTargetScreen: { identifier in
                events.append("screen:\(identifier)")
            },
            applyNotchPlacement: { placement in
                events.append("placement:\(Int(placement.closedFrame.width))")
            },
            showNotchPanel: {
                events.append("show")
            },
            hideNotchPanel: {
                events.append("hide")
            },
            closeNotchPanel: {
                events.append("close")
            }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 180, height: 40),
            expandedFrame: DisplayFrame(x: 0, y: 0, width: 420, height: 320),
            anchor: DisplayPoint(x: 100, y: 20),
            safeAreaAdjustment: 0
        )

        let result = executor.execute([
            .createNotchPanel,
            .installNotchEventMonitors,
            .applyTargetScreen("built-in"),
            .applyNotchPlacement(placement),
            .showNotchPanel,
            .hideNotchPanel,
            .removeNotchEventMonitors,
            .closeNotchPanel
        ])

        XCTAssertEqual(events, [
            "create",
            "install-monitors",
            "screen:built-in",
            "placement:180",
            "show",
            "hide",
            "remove-monitors",
            "close"
        ])
        XCTAssertEqual(result.executedIntents, [
            .createNotchPanel,
            .installNotchEventMonitors,
            .applyTargetScreen("built-in"),
            .applyNotchPlacement(placement),
            .showNotchPanel,
            .hideNotchPanel,
            .removeNotchEventMonitors,
            .closeNotchPanel
        ])
    }

    @MainActor
    func testExecutorAppliesRuntimeOwnerIntentsInOrder() {
        var events: [String] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            startRuntimeOwner: { owner in
                events.append("start:\(owner.rawValue)")
            },
            stopRuntimeOwner: { owner in
                events.append("stop:\(owner.rawValue)")
            }
        )

        let result = executor.execute([
            .startRuntimeOwner(.bridgeServer),
            .startRuntimeOwner(.sessionCoordinator),
            .stopRuntimeOwner(.bridgeServer)
        ])

        XCTAssertEqual(events, [
            "start:bridgeServer",
            "start:sessionCoordinator",
            "stop:bridgeServer"
        ])
        XCTAssertEqual(result.executedIntents, [
            .startRuntimeOwner(.bridgeServer),
            .startRuntimeOwner(.sessionCoordinator),
            .stopRuntimeOwner(.bridgeServer)
        ])
    }

    @MainActor
    func testExecutorAppliesLifecycleAndRouteIntentsInOrder() {
        var events: [String] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            applyLifecycleStep: { step in
                events.append("lifecycle:\(step.rawValue)")
            },
            showIsland: {
                events.append("show-island")
            },
            openSettings: { link in
                events.append("settings:\(link?.section.rawValue ?? "none")")
            },
            showOnboarding: {
                events.append("onboarding")
            },
            quitApplication: {
                events.append("quit")
            },
            ignoreMenuCommand: { command in
                events.append("ignored:\(command)")
            }
        )
        let settingsLink = SettingsDeepLink(section: .general)

        let result = executor.execute([
            .lifecycle(.createRuntime),
            .showIsland,
            .openSettings(settingsLink),
            .showOnboarding,
            .ignoredMenuCommand(.quit),
            .quitApplication
        ])

        XCTAssertEqual(events, [
            "lifecycle:createRuntime",
            "show-island",
            "settings:general",
            "onboarding",
            "ignored:quit",
            "quit"
        ])
        XCTAssertEqual(result.executedIntents, [
            .lifecycle(.createRuntime),
            .showIsland,
            .openSettings(settingsLink),
            .showOnboarding,
            .ignoredMenuCommand(.quit),
            .quitApplication
        ])
    }

    @MainActor
    func testExecutorAppliesOverlayIntent() {
        var actions: [OverlayControllerAction] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            applyOverlayAction: { action in
                actions.append(action)
            }
        )
        let action = OverlayControllerAction.routeAction(.openSettings)

        let result = executor.execute([
            .overlay(action)
        ])

        XCTAssertEqual(actions, [action])
        XCTAssertEqual(result.executedIntents, [.overlay(action)])
    }

    @MainActor
    func testExecutorAppliesPreferenceAndMaintenanceIntentsInOrder() {
        var events: [String] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            setDockIconVisible: { isVisible in
                events.append("dock:\(isVisible)")
            },
            setLaunchAtLoginEnabled: { isEnabled in
                events.append("login:\(isEnabled)")
            },
            checkForUpdates: {
                events.append("updates")
            },
            exportDiagnostics: {
                events.append("diagnostics")
            }
        )

        let result = executor.execute([
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(false),
            .checkForUpdates,
            .exportDiagnostics
        ])

        XCTAssertEqual(events, [
            "dock:true",
            "login:false",
            "updates",
            "diagnostics"
        ])
        XCTAssertEqual(result.executedIntents, [
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(false),
            .checkForUpdates,
            .exportDiagnostics
        ])
    }

    private static var singleCommandMenuSnapshot: StatusItemMenuSnapshot {
        StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            entries: [
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Open Settings",
                    command: .openSettings,
                    isEnabled: true
                )
            ]
        )
    }

    @MainActor
    private func executeRow(
        id: String,
        intents: [AppShellPlatformLaunchIntent]
    ) -> PlatformIntentExecutorMatrixRow {
        var events: [String] = []
        let executor = MyVibeIslandAppKitPlatformIntentExecutor(
            applyStatusItemMenu: { snapshot in
                events.append("menu:\(snapshot.surface.rawValue):\(snapshot.entries.count)")
            },
            applyLifecycleStep: { step in
                events.append("lifecycle:\(step.rawValue)")
            },
            startRuntimeOwner: { owner in
                events.append("start:\(owner.rawValue)")
            },
            stopRuntimeOwner: { owner in
                events.append("stop:\(owner.rawValue)")
            },
            createNotchPanel: {
                events.append("create-notch")
            },
            installNotchEventMonitors: {
                events.append("install-monitors")
            },
            removeNotchEventMonitors: {
                events.append("remove-monitors")
            },
            applyTargetScreen: { identifier in
                events.append("screen:\(identifier)")
            },
            applyNotchPlacement: { placement in
                events.append("placement:\(Int(placement.closedFrame.width))")
            },
            showNotchPanel: {
                events.append("show-notch")
            },
            hideNotchPanel: {
                events.append("hide-notch")
            },
            closeNotchPanel: {
                events.append("close-notch")
            },
            showIsland: {
                events.append("show-island")
            },
            openSettings: { link in
                events.append("settings:\(link?.section.rawValue ?? "none"):\(link?.rowId ?? "none")")
            },
            showOnboarding: {
                events.append("onboarding")
            },
            setDockIconVisible: { isVisible in
                events.append("dock:\(isVisible)")
            },
            setLaunchAtLoginEnabled: { isEnabled in
                events.append("login:\(isEnabled)")
            },
            checkForUpdates: {
                events.append("updates")
            },
            exportDiagnostics: {
                events.append("diagnostics")
            },
            quitApplication: {
                events.append("quit")
            },
            ignoreMenuCommand: { command in
                events.append("ignored:\(command.summary)")
            },
            applyOverlayAction: { action in
                events.append("overlay:\(action.kindSummary)")
            }
        )

        let result = executor.execute(intents)
        return PlatformIntentExecutorMatrixRow(
            id: id,
            inputIntentCount: intents.count,
            executedIntentCount: result.executedIntents.count,
            events: events
        )
    }
}

private struct PlatformIntentExecutorMatrixFixture: Codable, Equatable {
    let rows: [PlatformIntentExecutorMatrixRow]
}

private struct PlatformIntentExecutorMatrixRow: Codable, Equatable {
    let id: String
    let inputIntentCount: Int
    let executedIntentCount: Int
    let events: [String]
}

private extension OverlayControllerAction {
    var kindSummary: String {
        switch self {
        case .renderPresentation:
            return "renderPresentation"
        case .renderIslandSurface:
            return "renderIslandSurface"
        case .applyPanelPlan:
            return "applyPanelPlan"
        case .routeAction:
            return "routeAction"
        case .recordDisplayReason:
            return "recordDisplayReason"
        }
    }
}

private extension AppCommand {
    var summary: String {
        switch self {
        case .openSettings:
            return "openSettings"
        case .checkForUpdates:
            return "checkForUpdates"
        case .exportDiagnostics:
            return "exportDiagnostics"
        case .toggleDockIcon:
            return "toggleDockIcon"
        case .toggleLaunchAtLogin:
            return "toggleLaunchAtLogin"
        case let .selectScreenMode(mode):
            return "selectScreenMode:\(mode.rawValue)"
        case .quit:
            return "quit"
        }
    }
}
