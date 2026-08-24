import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitProductionCompositionTests: XCTestCase {
    @MainActor
    func testSwitcherCandidateSynchronizationDoesNotOpenUntilShortcutWriterRequestsIt() throws {
        let composition = try makeSwitcherComposition()
        let coordinator = composition.switcherCoordinator

        coordinator.syncAvailableSessions(
            sessionIDs: ["first", "second", "third"],
            focusedID: "second"
        )

        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertNil(coordinator.state.highlightedID)

        coordinator.openFromShortcut()

        XCTAssertTrue(coordinator.state.isOpen)
        XCTAssertEqual(coordinator.state.highlightedID, "second")
    }

    @MainActor
    func testProductionSwitcherCallbacksMutateSharedCoordinatorState() throws {
        let composition = try makeSwitcherComposition()
        let coordinator = composition.switcherCoordinator

        coordinator.open(sessionIDs: ["first", "second", "third"], highlighted: "second")
        composition.originalUnifiedHostingRenderer.navigateSwitcher(.down, reverse: false)

        XCTAssertEqual(coordinator.state.highlightedID, "third")
        composition.originalUnifiedHostingRenderer.collapseSwitcher()
        XCTAssertFalse(coordinator.state.isOpen)
    }

    @MainActor
    func testProductionSwitcherOccurrenceNavigationUpdatesRetainedPresentation() throws {
        let composition = try makeSwitcherComposition()
        let duplicate = AgentSession(
            id: "same",
            source: "codex",
            cwd: "/tmp/same",
            originalStatus: .processing,
            repoName: "same"
        )
        composition.overlayController.renderIslandSurface(IslandSurfaceRenderList(
            sections: IslandSurfaceSections(
                sessions: [duplicate, duplicate],
                visibleSections: [.expandedPanel, .sessionCards, .switcher],
                displayStatus: .switcher,
                layoutMode: .expanded,
                onboardingStep: nil,
                primarySessionIds: ["same", "same"],
                focusedSessionId: "same"
            )
        ))

        composition.switcherCoordinator.openFromShortcut()
        composition.switcherCoordinator.navigate(.up)

        guard case let .switcher(descriptor) = composition.originalUnifiedHostingRenderer.model?.presentation else {
            return XCTFail("Expected retained switcher presentation")
        }
        XCTAssertEqual(descriptor.highlightedID, "same")
        XCTAssertEqual(descriptor.highlightedIndex, 1)
    }

    @MainActor
    func testProductionSwitcherEnterExecutesRuntimeJumpAndCollapses() async throws {
        let session = SessionState(
            sessionId: "exact",
            source: "codex",
            cwd: "/tmp/project",
            jumpInput: JumpInput(sessionId: "exact", source: "codex", cwd: "/tmp/project", tmuxPane: "%1")
        )
        let runtime = AppRuntime(
            sessionCoordinator: SessionCoordinator(sessions: [session]),
            jumpRunner: ProductionSwitcherRecordingJumpRunner()
        )
        let composition = try makeSwitcherComposition(runtime: runtime)
        composition.switcherCoordinator.open(sessionIDs: ["other", "exact"], highlighted: "exact")

        composition.originalUnifiedHostingRenderer.submitHighlightedSwitcher()

        XCTAssertEqual(composition.localSessionJumpCoordinator?.lastJumpedSessionId, "exact")
        for _ in 0..<100 where composition.localSessionJumpCoordinator?.lastJumpResult == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(composition.localSessionJumpCoordinator?.lastJumpResult?.status, .executed)
        XCTAssertFalse(composition.switcherCoordinator.state.isOpen)
    }

    @MainActor
    func testProductionSwitcherFocusCallbacksRoutePanelActions() throws {
        let composition = try makeSwitcherComposition()

        composition.originalUnifiedHostingRenderer.requestSwitcherFocus()
        XCTAssertEqual(composition.overlayController.lastForwardedInteractionAction, .requestKeyboardFocus)

        composition.originalUnifiedHostingRenderer.releaseSwitcherFocus()
        XCTAssertEqual(composition.overlayController.lastForwardedInteractionAction, .releaseKeyboardFocus)
    }

    @MainActor
    func testProductionSwitcherLifecycleStartsAndStopsOwnedEventMonitor() throws {
        let composition = try makeSwitcherComposition()
        composition.switcherCoordinator.open(sessionIDs: ["session"], highlighted: nil)
        XCTAssertTrue(composition.switcherEventMonitor.isStarted)

        composition.originalUnifiedHostingRenderer.collapseSwitcher()
        XCTAssertFalse(composition.switcherEventMonitor.isStarted)

        composition.switcherCoordinator.open(sessionIDs: ["session"], highlighted: nil)
        _ = composition.platformIntentExecutor.execute([.hideNotchPanel])
        XCTAssertFalse(composition.switcherEventMonitor.isStarted)

        composition.switcherCoordinator.open(sessionIDs: ["session"], highlighted: nil)
        _ = composition.platformIntentExecutor.execute([.removeNotchEventMonitors])
        XCTAssertFalse(composition.switcherEventMonitor.isStarted)

        composition.switcherCoordinator.open(sessionIDs: ["session"], highlighted: nil)
        _ = composition.platformIntentExecutor.execute([.closeNotchPanel])
        XCTAssertFalse(composition.switcherEventMonitor.isStarted)
    }

    @MainActor
    func testConfiguredCarbonHotKeysOpenSwitcherJumpHighlightedAndTearDown() throws {
        let session = SessionState(
            sessionId: "exact",
            source: "codex",
            cwd: "/tmp/project",
            jumpInput: JumpInput(sessionId: "exact", source: "codex", cwd: "/tmp/project")
        )
        let runtime = AppRuntime(
            sessionCoordinator: SessionCoordinator(sessions: [session]),
            jumpRunner: ProductionSwitcherRecordingJumpRunner()
        )
        runtime.setActiveSessionId("exact")
        let carbon = ProductionCarbonSystemRecorder()
        let settings = ShortcutSettings(globalShortcuts: [
            hotKeySpec(id: "open", keyCode: 48, action: .toggleIsland),
        ], switcherShortcuts: [
            hotKeySpec(id: "jump", keyCode: 36, action: .jumpToTerminal, scope: .switcherPanel),
        ])
        let composition = try makeSwitcherComposition(
            runtime: runtime,
            shortcutSettings: settings,
            makeCarbonRuntime: { callback in
                MyVibeIslandAppKitCarbonHotKeyRuntime(
                    onHotKey: callback,
                    installHandler: carbon.install,
                    removeHandler: carbon.removeHandler,
                    registerHotKey: carbon.register,
                    unregisterHotKey: carbon.unregister
                )
            }
        )
        composition.notchViewModelController.replaceIslandRuntimeSnapshot(runtime.islandRuntimeSnapshot())
        XCTAssertTrue(composition.lifecycleController.apply(.startRuntimeCoordinators))

        try carbon.fire(carbonID: 1)
        XCTAssertTrue(composition.switcherCoordinator.state.isOpen)
        XCTAssertEqual(composition.switcherCoordinator.state.highlightedID, "exact")

        try carbon.fire(carbonID: 2)
        XCTAssertEqual(composition.localSessionJumpCoordinator?.lastJumpedSessionId, "exact")
        XCTAssertFalse(composition.switcherCoordinator.state.isOpen)

        XCTAssertTrue(composition.lifecycleController.apply(.unregisterShortcuts))
        XCTAssertEqual(Set(carbon.unregisteredIDs), ["open", "jump"])
        XCTAssertEqual(carbon.removeHandlerCount, 1)
    }

    @MainActor
    func testProductionWiresBridgeAndTaskFiveLocalWatchersOwners() throws {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            localWatcherHomeDirectory: URL(fileURLWithPath: "/tmp/my-vibe-island-task6-empty-\(UUID().uuidString)")
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task6.\(UUID().uuidString)"))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([
            .startRuntimeOwner(.bridgeServer),
            .startRuntimeOwner(.sessionCoordinator)
        ])

        XCTAssertTrue(runtime.status().isBridgeRunning)
        XCTAssertTrue(composition.runtimeOwnerController.runningOwners.contains(.bridgeServer))
        XCTAssertTrue(composition.runtimeOwnerController.runningOwners.contains(.sessionCoordinator))
        XCTAssertFalse(composition.runtimeOwnerController.runningOwners.contains(.usageCoordinator))
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .usageCoordinator),
            .unavailable("usage coordinator is owned by AppKit composition")
        )

        _ = composition.platformIntentExecutor.execute([
            .stopRuntimeOwner(.sessionCoordinator),
            .stopRuntimeOwner(.bridgeServer)
        ])

        XCTAssertFalse(runtime.status().isBridgeRunning)
        XCTAssertEqual(composition.runtimeOwnerController.runningOwners, [])
    }

    @MainActor
    func testProductionRoutesSessionJumpThroughLocalCoordinator() throws {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task6.\(UUID().uuidString)"))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.selectSession(sessionId: "session-1")))
        ])

        XCTAssertEqual(composition.localSessionJumpCoordinator?.lastSelectedSessionId, "session-1")
    }

    @MainActor
    func testApplicationTerminationStopsOnlyObservedProductionOwnersInReverseOrder() throws {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            localWatcherHomeDirectory: URL(fileURLWithPath: "/tmp/my-vibe-island-task6-empty-\(UUID().uuidString)")
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task6.\(UUID().uuidString)"))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )
        let delegate = MyVibeIslandAppKitDelegate(
            executePlatformIntents: { intents in
                composition.platformIntentExecutor.execute(intents)
            }
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertTrue(runtime.status().isBridgeRunning)
        XCTAssertTrue(runtime.areLocalSessionWatchersRunning)
        let coordinatorState = try XCTUnwrap(delegate.state.coordinatorState)
        XCTAssertEqual(
            coordinatorState.shellState.runtimeSnapshot.owners.filter { $0.isRunning }.map { $0.owner },
            [.bridgeServer, .sessionCoordinator]
        )
        XCTAssertEqual(
            delegate.state.runtimeOwnerFailures[.usageCoordinator],
            "usage coordinator is owned by AppKit composition"
        )

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertFalse(runtime.status().isBridgeRunning)
        XCTAssertFalse(runtime.areLocalSessionWatchersRunning)
        XCTAssertEqual(
            delegate.lastPlan?.intents.compactMap { intent -> AppRuntimeOwner? in
                if case let .stopRuntimeOwner(owner) = intent { return owner }
                return nil
            },
            [.sessionCoordinator, .bridgeServer]
        )
    }

    @MainActor
    func testProductionLegacyRoutesCallRuntimeAndRejectUnknownRequests() throws {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task6.\(UUID().uuidString)"))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.resolveAction(requestId: "missing", sessionId: "missing"))),
            .overlay(.routeAction(.answerQuestion(requestId: "missing", sessionId: "missing")))
        ])

        XCTAssertEqual(composition.localSessionJumpCoordinator?.lastLegacyResolution?.kind, .answer)
        XCTAssertTrue(runtime.actionableRequests().isEmpty)
    }

    @MainActor
    private func makeSwitcherComposition(
        runtime: AppRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests()),
        shortcutSettings: ShortcutSettings = ShortcutSettings(),
        makeCarbonRuntime: @escaping (@escaping @MainActor (String) -> Void) -> MyVibeIslandAppKitCarbonHotKeyRuntime = {
            MyVibeIslandAppKitCarbonHotKeyRuntime(onHotKey: $0)
        }
    ) throws -> MyVibeIslandAppKitPlatformComposition {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task8A.\(UUID().uuidString)"))
        return MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            shortcutSettings: shortcutSettings,
            makeCarbonHotKeyRuntime: makeCarbonRuntime,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 32,
                    frameWidth: 1512,
                    auxiliaryTopLeftWidth: 663,
                    auxiliaryTopRightWidth: 664,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
                )
            }
        )
    }

    private func hotKeySpec(
        id: String,
        keyCode: Int,
        action: ShortcutAction,
        scope: ShortcutScope = .persistentGlobal
    ) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: id,
            action: action,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: keyCode, characters: "", modifiers: [.command]),
            scope: scope
        )
    }
}

private struct ProductionSwitcherRecordingJumpRunner: TerminalJumpActionRunning {
    func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        .succeeded(action.handlerId ?? "jump")
    }
}

@MainActor
private final class ProductionCarbonSystemRecorder {
    private(set) var removeHandlerCount = 0
    private(set) var unregisteredIDs: [String] = []
    private var callback: ((UInt32) -> Void)?

    func install(_ callback: @escaping (UInt32) -> Void) -> Any? {
        self.callback = callback
        return NSObject()
    }

    func removeHandler(_ token: Any) {
        removeHandlerCount += 1
        callback = nil
    }

    func register(_ request: MyVibeIslandAppKitCarbonHotKeyRegistrationRequest) -> Any? {
        NSObject()
    }

    func unregister(_ id: String, _ token: Any) {
        unregisteredIDs.append(id)
    }

    func fire(carbonID: UInt32) throws {
        try XCTUnwrap(callback)(carbonID)
    }
}
