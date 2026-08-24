import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitShellCommandDispatcherTests: XCTestCase {
    @MainActor
    func testShellCommandDispatcherMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShellCommandDispatcherMatrixFixture.self,
            from: try AppFixtureLoader.data("app/shell-command-dispatcher-matrix")
        )

        let actual = ShellCommandDispatcherMatrixFixture(rows: [
            dispatchRow(id: "menu-open-settings") { dispatcher in
                dispatcher.dispatch(.openSettings)
            },
            dispatchRow(id: "overlay-open-settings") { dispatcher in
                dispatcher.dispatchOverlayAction(.openSettings)
            },
            dispatchRow(id: "overlay-check-for-updates") { dispatcher in
                dispatcher.dispatchOverlayAction(.appCommand(.checkForUpdates))
            },
            screenSelectionRow(),
            dispatchRow(id: "overlay-select-session") { dispatcher in
                dispatcher.dispatchOverlayAction(.selectSession(sessionId: "session-1"))
            },
            dispatchRow(id: "overlay-jump-session") { dispatcher in
                dispatcher.dispatchOverlayAction(.jumpToSession(sessionId: "session-1"))
            },
            dispatchRow(id: "overlay-resolve-action") { dispatcher in
                dispatcher.dispatchOverlayAction(.resolveAction(requestId: "request-1", sessionId: "session-1"))
            },
            dispatchRow(id: "overlay-answer-question") { dispatcher in
                dispatcher.dispatchOverlayAction(.answerQuestion(requestId: "request-1", sessionId: "session-1"))
            }
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testDispatcherRoutesStatusMenuCommandThroughShellAndExecutesPlatformIntents() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                openSettings: { link in
                    events.append("settings:\(link?.section.rawValue ?? "none")")
                },
                applyOverlayAction: { _ in
                    events.append("overlay")
                }
            )
        )

        let result = dispatcher.dispatch(.openSettings)

        XCTAssertEqual(result.coordinatorPlan.commands, [.menu(.openSettings)])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil)
        ])
        XCTAssertEqual(events, [
            "overlay",
            "settings:none"
        ])
        XCTAssertEqual(dispatcher.state, result.coordinatorPlan.nextState)
    }

    @MainActor
    func testDispatcherRoutesScreenModeCommandsThroughScreenSelectionController() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let screenSelectionController = MyVibeIslandAppKitScreenSelectionController(
            snapshot: ScreenSelectionSnapshot(
                availableScreens: [
                    ScreenDescriptor(identifier: "built-in", displayName: "Built-in", isBuiltIn: true, hasNotch: true, isMain: false),
                    ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: false, hasNotch: false, isMain: true)
                ],
                target: ScreenTarget(identifier: "built-in", displayName: "Built-in", isBuiltIn: true, isMain: false)
            ),
            applyTargetScreen: { target in
                events.append("screen:\(target.identifier)")
            }
        )
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            screenSelectionController: screenSelectionController,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatch(.selectScreenMode(.mainDisplay))

        XCTAssertEqual(result.coordinatorPlan.commands, [.menu(.selectScreenMode(.mainDisplay))])
        XCTAssertEqual(screenSelectionController.snapshot.mode, .mainDisplay)
        XCTAssertEqual(screenSelectionController.snapshot.target?.identifier, "built-in")
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testDispatcherRoutesOverlayOpenSettingsThroughShellCommandPath() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                openSettings: { _ in
                    events.append("settings")
                },
                applyOverlayAction: { _ in
                    events.append("overlay")
                }
            )
        )

        let result = dispatcher.dispatchOverlayAction(.openSettings)

        XCTAssertEqual(result.coordinatorPlan.commands, [.menu(.openSettings)])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil)
        ])
        XCTAssertEqual(events, [
            "overlay",
            "settings"
        ])
    }

    @MainActor
    func testDispatcherRoutesOverlayAppCommandThroughShellCommandPath() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                checkForUpdates: {
                    events.append("updates")
                },
                applyOverlayAction: { _ in
                    events.append("overlay")
                }
            )
        )

        let result = dispatcher.dispatchOverlayAction(.appCommand(.checkForUpdates))

        XCTAssertEqual(result.coordinatorPlan.commands, [.menu(.checkForUpdates)])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [
            .overlay(.routeAction(.appCommand(.checkForUpdates))),
            .checkForUpdates
        ])
        XCTAssertEqual(events, [
            "overlay",
            "updates"
        ])
    }

    @MainActor
    func testDispatcherRoutesOverlayJumpToInjectedBoundaryWithoutExecutingTerminalCommands() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            jumpToSession: { sessionId in
                events.append("jump:\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatchOverlayAction(.jumpToSession(sessionId: "session-1"))

        XCTAssertEqual(result.coordinatorPlan.commands, [])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [])
        XCTAssertEqual(events, ["jump:session-1"])
    }

    @MainActor
    func testDispatcherRoutesOverlaySelectSessionToInjectedBoundaryWithoutMutatingStorage() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            selectSession: { sessionId in
                events.append("select:\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatchOverlayAction(.selectSession(sessionId: "session-1"))

        XCTAssertEqual(result.coordinatorPlan.commands, [])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [])
        XCTAssertEqual(events, ["select:session-1"])
    }

    @MainActor
    func testDispatcherRoutesOverlayResolveActionToInjectedBoundaryWithoutResolvingRequests() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            resolveAction: { requestId, sessionId in
                events.append("resolve:\(requestId):\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatchOverlayAction(
            .resolveAction(requestId: "request-1", sessionId: "session-1")
        )

        XCTAssertEqual(result.coordinatorPlan.commands, [])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [])
        XCTAssertEqual(events, ["resolve:request-1:session-1"])
    }

    @MainActor
    func testDispatcherRoutesOverlayAnswerQuestionToInjectedBoundaryWithoutResolvingRequests() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            answerQuestion: { requestId, sessionId in
                events.append("answer:\(requestId):\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatchOverlayAction(
            .answerQuestion(requestId: "request-1", sessionId: "session-1")
        )

        XCTAssertEqual(result.coordinatorPlan.commands, [])
        XCTAssertEqual(result.platformExecutionResult.executedIntents, [])
        XCTAssertEqual(events, ["answer:request-1:session-1"])
    }

    @MainActor
    func testDispatcherPublishesLastDispatchResultForOrchestration() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let menuResult = dispatcher.dispatch(.openSettings)

        XCTAssertEqual(dispatcher.lastDispatchResult?.coordinatorPlan.commands, menuResult.coordinatorPlan.commands)
        XCTAssertEqual(
            dispatcher.lastDispatchResult?.platformExecutionResult.executedIntents,
            menuResult.platformExecutionResult.executedIntents
        )

        let overlayResult = dispatcher.dispatchOverlayAction(.selectSession(sessionId: "session-1"))

        XCTAssertEqual(dispatcher.lastDispatchResult?.coordinatorPlan.commands, overlayResult.coordinatorPlan.commands)
        XCTAssertEqual(dispatcher.lastDispatchResult?.platformExecutionResult.executedIntents, [])
    }

    @MainActor
    private func dispatchRow(
        id: String,
        run: (MyVibeIslandAppKitShellCommandDispatcher) -> MyVibeIslandAppKitShellCommandDispatchResult
    ) -> ShellCommandDispatcherMatrixRow {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            selectSession: { sessionId in
                events.append("select:\(sessionId)")
            },
            jumpToSession: { sessionId in
                events.append("jump:\(sessionId)")
            },
            resolveAction: { requestId, sessionId in
                events.append("resolve:\(requestId):\(sessionId)")
            },
            answerQuestion: { requestId, sessionId in
                events.append("answer:\(requestId):\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                openSettings: { link in
                    events.append("settings:\(link?.section.rawValue ?? "none")")
                },
                checkForUpdates: {
                    events.append("updates")
                },
                applyOverlayAction: { action in
                    events.append("overlay:\(action.kindSummary)")
                }
            )
        )

        let result = run(dispatcher)
        return ShellCommandDispatcherMatrixRow(
            id: id,
            commandSummaries: result.coordinatorPlan.commands.map(\.summary),
            executedIntentCount: result.platformExecutionResult.executedIntents.count,
            events: events,
            updatedLastResult: dispatcher.lastDispatchResult != nil
        )
    }

    @MainActor
    private func screenSelectionRow() -> ShellCommandDispatcherMatrixRow {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let screenSelectionController = MyVibeIslandAppKitScreenSelectionController(
            snapshot: ScreenSelectionSnapshot(
                availableScreens: [
                    ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: false, hasNotch: false, isMain: true),
                    ScreenDescriptor(identifier: "built-in", displayName: "Built-in", isBuiltIn: true, hasNotch: true, isMain: false)
                ],
                target: ScreenTarget(identifier: "built-in", displayName: "Built-in", isBuiltIn: true, isMain: false)
            ),
            applyTargetScreen: { target in
                events.append("screen:\(target.identifier)")
            }
        )
        let dispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            screenSelectionController: screenSelectionController,
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )

        let result = dispatcher.dispatch(.selectScreenMode(.mainDisplay))
        return ShellCommandDispatcherMatrixRow(
            id: "menu-screen-mode",
            commandSummaries: result.coordinatorPlan.commands.map(\.summary),
            executedIntentCount: result.platformExecutionResult.executedIntents.count,
            events: events,
            updatedLastResult: dispatcher.lastDispatchResult != nil
        )
    }
}

private struct ShellCommandDispatcherMatrixFixture: Codable, Equatable {
    let rows: [ShellCommandDispatcherMatrixRow]
}

private struct ShellCommandDispatcherMatrixRow: Codable, Equatable {
    let id: String
    let commandSummaries: [String]
    let executedIntentCount: Int
    let events: [String]
    let updatedLastResult: Bool
}

private extension AppShellCommand {
    var summary: String {
        switch self {
        case .launch:
            return "launch"
        case .reopen:
            return "reopen"
        case .terminate:
            return "terminate"
        case .overlay:
            return "overlay"
        case let .menu(command):
            return "menu:\(command.summary)"
        case .replacePresentation:
            return "replacePresentation"
        case .replaceMenuSnapshot:
            return "replaceMenuSnapshot"
        case .replacePlacement:
            return "replacePlacement"
        case let .runtimeOwnerObserved(owner, isRunning):
            return "runtimeOwnerObserved:\(owner.rawValue):\(isRunning)"
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
