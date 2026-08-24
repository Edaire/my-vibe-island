import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitPlatformCompositionTests: XCTestCase {
    func testProductionCompositionInjectsForegroundTerminalEvidenceForV3CompletionGate() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitPlatformComposition.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("let activeCliTTYProvider = ActiveCliTTYProvider()"))
        XCTAssertTrue(source.contains("automaticExpansionFocus:"))
        XCTAssertTrue(source.contains("NSWorkspace.shared.frontmostApplication?.bundleIdentifier"))
        XCTAssertTrue(source.contains("activeCliTTYProvider.activeTTYs(for: sessions)"))
    }

    private final class BridgeResponseBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<BridgeResponse, Error>?

        func record(_ result: Result<BridgeResponse, Error>) {
            lock.lock()
            self.result = result
            lock.unlock()
        }

        func response() throws -> BridgeResponse {
            lock.lock()
            defer { lock.unlock() }
            return try XCTUnwrap(result).get()
        }
    }

    @MainActor
    func testProductionParsesLayoutModeDefaultsMatrix() throws {
        let cases: [(String?, Bool, NotchLayoutMode)] = [
            ("normal", false, .regular),
            ("compact", true, .compact),
            (nil, true, .compact),
            ("unknown", true, .compact),
        ]

        for (storedValue, expectedCompactMode, expectedLayoutMode) in cases {
            let defaults = try XCTUnwrap(UserDefaults(
                suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
            ))
            if let storedValue {
                defaults.set(storedValue, forKey: "layoutMode")
            }
            let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
            defer { runtime.stop() }
            let composition = MyVibeIslandAppKitPlatformComposition.production(
                runtime: runtime,
                defaults: defaults,
                soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
            )

            XCTAssertEqual(
                composition.notchViewModelController.state.localPreferences.compactMode,
                expectedCompactMode,
                "stored layoutMode: \(storedValue as Any)"
            )
            XCTAssertEqual(
                NotchLayoutMode(
                    displayState: .closed,
                    preferences: composition.notchViewModelController.state.localPreferences
                ),
                expectedLayoutMode,
                "stored layoutMode: \(storedValue as Any)"
            )
        }
    }

    @MainActor
    func testProductionFirstExternalClosedRenderUsesCompactDefaultSize() async throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            notchPanelController: notchPanelController,
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 0,
                    frameWidth: 1920,
                    auxiliaryTopLeftWidth: 0,
                    auxiliaryTopRightWidth: 0,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1050)
                )
            }
        )

        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot())

        let host = try XCTUnwrap(originalCompactHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 206, height: 30))

        // IDA sub_100494930: the AppKit panel uses the renderer's maximum
        // expanded host frame, not the compact visual surface frame.
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(
            notchPanelController.lastFrame,
            composition.originalUnifiedHostingRenderer.interactionGeometry?.expandedFrame
        )
    }

    @MainActor
    func testProductionExpandedSurfaceDoesNotResizeTheTransparentHostPanel() async throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            notchPanelController: notchPanelController,
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 0,
                    frameWidth: 1920,
                    auxiliaryTopLeftWidth: 0,
                    auxiliaryTopRightWidth: 0,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1050)
                )
            }
        )

        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot())
        composition.notchViewModelController.toggleExpanded()
        try await Task.sleep(nanoseconds: 80_000_000)

        let visibleSurface = try XCTUnwrap(
            composition.originalUnifiedHostingRenderer.interactionGeometry?.expandedFrame
        )
        XCTAssertEqual(visibleSurface.width, 640)
        XCTAssertEqual(
            notchPanelController.lastFrame,
            DisplayFrame(x: 620, y: 500, width: 680, height: 580)
        )
        XCTAssertNotEqual(notchPanelController.lastFrame, visibleSurface)
    }

    @MainActor
    func testProductionCompositionUsesConcreteSoundExecutor() {
        let composition = MyVibeIslandAppKitPlatformComposition.production()

        XCTAssertTrue(composition.soundPlaybackController.usesConcreteExecutor)
    }

    @MainActor
    func testProductionCompositionStartsAndStopsInjectedLocalBridge() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])

        XCTAssertTrue(runtime.status().isBridgeRunning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: socketPath))

        _ = composition.platformIntentExecutor.execute([.stopRuntimeOwner(.bridgeServer)])

        XCTAssertFalse(runtime.status().isBridgeRunning)
        XCTAssertFalse(FileManager.default.fileExists(atPath: socketPath))
    }

    @MainActor
    func testProductionCompositionInstallsBundledBridgeThroughIntegrationOwner() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        var installCount = 0
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            installBundledBridge: { installCount += 1 }
        )

        composition.runtimeOwnerController.start(.integrationCoordinator)

        XCTAssertEqual(installCount, 1)
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .integrationCoordinator),
            .available
        )
        XCTAssertTrue(composition.runtimeOwnerController.runningOwners.contains(.integrationCoordinator))
        XCTAssertEqual(
            composition.runtimeOwnerController.result(for: .integrationCoordinator),
            .started(.integrationCoordinator)
        )
    }

    @MainActor
    func testProductionCompositionLoadsPersistedShortcutSettingsByDefault() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let expected = ShortcutSettings().withKeyboardShortcutsEnabled(false)
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }

        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: {
                SettingsSnapshot(shortcuts: expected)
            }
        )

        XCTAssertEqual(composition.shortcutManagerController.settings, expected)
        XCTAssertEqual(composition.shortcutCoordinatorController.settings, expected)
    }

    @MainActor
    func testProductionNotificationDeliveryPreservesCurrentIslandSurface() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            automaticExpansionFocusProvider: { _ in
                V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys901"]
                )
            }
        )
        let session = AgentSession(
            id: "completed-session",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true,
            jumpInput: JumpInput(
                sessionId: "completed-session",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "ttys901"
            )
        )
        let preview = SessionCardPreview(session: session)
        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [preview],
            actionRequestPreviews: []
        ))
        let notification = PeekNotification(
            id: "completed-session:completion",
            category: .sessionCompleted,
            sessionId: preview.sessionId,
            agent: preview.sourceBadge,
            title: preview.displayTitle,
            body: preview.activitySummary ?? preview.statusBadge,
            severity: .info,
            primaryAction: .jump,
            createdAt: "2026-07-18T00:00:00Z",
            dwellSeconds: 8,
            dedupeKey: "completed-session:completion",
            soundCategory: .completion,
            source: preview.sourceBadge
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        XCTAssertEqual(
            composition.notchViewModelController.state.notificationPreviews.map(\.sessionId),
            ["completed-session"]
        )
        XCTAssertEqual(
            composition.notchViewModelController.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
        guard case let .expanded(descriptor) = composition.originalUnifiedHostingRenderer.model?.presentation else {
            return XCTFail("Expected original single-session expanded notification")
        }
        XCTAssertEqual(descriptor.contentPlan.displayRows.map(\.id), ["completed-session"])
        XCTAssertEqual(descriptor.surfaceSize.width, 640)
        XCTAssertLessThan(descriptor.surfaceSize.height, 200)
    }

    @MainActor
    func testProductionCompletionUsesCompactFlashWhenPersistedAutoExpandIsDisabled() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: {
                SettingsSnapshot(behaviour: BehaviourSettings(autoExpandOnTaskComplete: false))
            }
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "completed-session",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        ))
        composition.notchViewModelController.replaceSessionPreviews([preview])
        let notification = PeekNotification(
            id: "completed-session:completion",
            category: .sessionCompleted,
            sessionId: preview.sessionId,
            agent: preview.sourceBadge,
            title: preview.displayTitle,
            body: preview.activitySummary ?? preview.statusBadge,
            severity: .info,
            primaryAction: .jump,
            createdAt: "2026-08-06T00:00:00Z",
            dwellSeconds: 8,
            dedupeKey: "completed-session:completion",
            soundCategory: .completion,
            source: preview.sourceBadge
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        XCTAssertEqual(
            composition.notchViewModelController.state.originalCompactRuntimeState.completionFlashTick,
            1
        )
        XCTAssertEqual(
            composition.notchViewModelController.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    @MainActor
    func testProductionCompletionAppliesV3CustomRuleOnlyAtDisplayDecisionBoundary() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let rulePayload = """
        {
          "customRules": [{
            "id": "7A9D7260-9C3D-4F89-A494-C0A9EB4CB10F",
            "enabled": true,
            "field": "firstUserPrompt",
            "matchType": "contains",
            "pattern": "__v3_policy_probe__",
            "caseSensitive": true,
            "createdAt": 0
          }],
          "disabledBuiltInIds": [],
          "version": 1
        }
        """
        defaults.set(
            try XCTUnwrap(rulePayload.data(using: .utf8)),
            forKey: V3SilenceRulesPreferenceStore.Key.snapshot
        )
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: {
                SettingsSnapshot(behaviour: BehaviourSettings(autoExpandOnTaskComplete: false))
            }
        )
        let session = AgentSession(
            id: "suppressed-completion",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            firstUserMessage: "__v3_policy_probe__",
            hasUnreadCompletion: true
        )
        let preview = SessionCardPreview(session: session)
        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [preview]
        ))
        let notification = PeekNotification(
            id: "suppressed-completion:completion",
            category: .sessionCompleted,
            sessionId: session.id,
            agent: preview.sourceBadge,
            title: preview.displayTitle,
            body: preview.activitySummary ?? preview.statusBadge,
            severity: .info,
            primaryAction: .jump,
            createdAt: "2026-08-18T00:00:00Z",
            dwellSeconds: 8,
            dedupeKey: "suppressed-completion:completion",
            soundCategory: .completion,
            source: preview.sourceBadge
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        XCTAssertEqual(composition.notchViewModelController.state.sessionPreviews, [preview])
        XCTAssertEqual(composition.notchViewModelController.state.originalCompactRuntimeState.completionFlashTick, 0)
        XCTAssertEqual(
            composition.notchViewModelController.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    @MainActor
    func testProductionCompletionSuppressesAutoExpandWhenQuietSceneIsActive() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let quietSceneMonitor = MyVibeIslandAppKitQuietSceneMonitor(
            enabled: [.screenObscured: true]
        )
        _ = quietSceneMonitor.setScreenObscured(true)
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            quietSceneMonitor: quietSceneMonitor
        )
        let preview = SessionCardPreview(session: AgentSession(
            id: "quiet-completed-session",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .ended,
            hasUnreadCompletion: true
        ))
        composition.notchViewModelController.replaceSessionPreviews([preview])
        let notification = PeekNotification(
            id: "quiet-completed-session:completion",
            category: .sessionCompleted,
            sessionId: preview.sessionId,
            agent: preview.sourceBadge,
            title: preview.displayTitle,
            body: preview.activitySummary ?? preview.statusBadge,
            severity: .info,
            primaryAction: .jump,
            createdAt: "2026-08-18T00:00:00Z",
            dwellSeconds: 8,
            dedupeKey: "quiet-completed-session:completion",
            soundCategory: .completion,
            source: preview.sourceBadge
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        XCTAssertTrue(composition.notchViewModelController.state.quietSceneCompletionPending)
        XCTAssertEqual(
            composition.notchViewModelController.state.overlayState.panelState.presentationState.displayState,
            .closed
        )
    }

    @MainActor
    func testPermissionNotificationExpandsOrdinaryIslandWithBlockingApproval() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )
        let request = ActionableRequest(
            requestId: "permission-1",
            sessionId: "permission-session",
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(prompt: "Allow date command?")
        )
        let session = AgentSession(
            id: "permission-session",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .waitingForApproval,
            actionableRequests: [request]
        )
        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [session],
            sessionPreviews: [SessionCardPreview(session: session)],
            actionRequestPreviews: [ActionRequestPreview(request: request)]
        ))
        let notification = PeekNotification(
            id: "permission-1",
            category: .permissionRequested,
            sessionId: session.id,
            agent: session.source,
            title: "Permission requested",
            body: "Allow date command?",
            severity: .blocking,
            createdAt: "2026-07-30T00:00:00Z",
            dwellSeconds: 8,
            soundCategory: .permission,
            source: session.source
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent
            )
        )

        guard case let .expanded(descriptor) = composition.originalUnifiedHostingRenderer.model?.presentation else {
            return XCTFail("Expected permission notification to expand the ordinary island")
        }
        XCTAssertEqual(descriptor.contentPlan.displayRows.map(\.id), [session.id])
        XCTAssertTrue(composition.notchViewModelController.state.overlayState.panelState.presentationState.interactionState.blockingActionVisible)
    }

    @MainActor
    func testCompletionRenderFocusesTheCompletedSessionWhenOtherSessionsAreVisible() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            automaticExpansionFocusProvider: { _ in
                V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys902"]
                )
            }
        )
        let active = AgentSession(
            id: "active-session",
            source: "codex",
            cwd: "/tmp/active",
            originalStatus: .processing,
            lastAssistantMessage: "Still working",
            lastUserMessage: "Keep working"
        )
        let completed = AgentSession(
            id: "completed-session",
            source: "codex",
            cwd: "/tmp/completed",
            originalStatus: .ended,
            lastAssistantMessage: "Current turn completed.",
            lastUserMessage: "Finish this turn",
            hasUnreadCompletion: true,
            jumpInput: JumpInput(
                sessionId: "completed-session",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "ttys902"
            )
        )
        composition.notchViewModelController.replaceIslandRuntimeSnapshot(IslandRuntimeSnapshot(
            sessions: [active, completed],
            sessionPreviews: [
                SessionCardPreview(session: active),
                SessionCardPreview(session: completed),
            ],
            actionRequestPreviews: []
        ))
        let notification = PeekNotification(
            id: "completed-session:completion",
            category: .sessionCompleted,
            sessionId: completed.id,
            agent: completed.source,
            title: "completed",
            body: "Current turn completed.",
            severity: .info,
            primaryAction: .jump,
            createdAt: "2026-07-18T00:00:00Z",
            dwellSeconds: 8,
            dedupeKey: "completed-session:completion",
            soundCategory: .completion,
            source: completed.source
        )

        _ = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        guard case let .expanded(descriptor) = composition.originalUnifiedHostingRenderer.model?.presentation else {
            return XCTFail("Expected completion render to expand the ordinary island")
        }
        XCTAssertEqual(descriptor.contentPlan.displayRows.map(\.id), [completed.id, active.id])
        XCTAssertEqual(descriptor.contentPlan.completionBodyRowID, completed.id)
        XCTAssertNil(descriptor.completionPreviewRow)
        XCTAssertEqual(
            descriptor.contentPlan.displayRows.first?.session.lastAssistantMessage,
            "Current turn completed."
        )
    }

    @MainActor
    func testProductionCompositionPublishesLocalBridgeSessionsToIslandSurface() async throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptors.append($0) },
            buildIslandSurfaceView: { _ in NSView() }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            overlayController: overlayController
        )
        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("live-session"),
                "cwd": .string("/tmp/live-project"),
            ]
        ))
        for _ in 0..<20 where composition.notchViewModelController.state.sessionPreviews.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(
            composition.notchViewModelController.state.sessionPreviews.map(\.sessionId),
            ["live-session"]
        )
        XCTAssertEqual(descriptors.last?.items.first?.sessionIds, ["live-session"])
    }

    @MainActor
    func testProductionRuntimePublishesCompletionPeek() async throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            automaticExpansionFocusProvider: { _ in
                V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys903"]
                )
            }
        )
        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])
        let client = BridgeClient(socketPath: socketPath)

        _ = try client.send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("completed-session"),
                "cwd": .string("/tmp/live-project"),
            ]
        ))
        for _ in 0..<20 where composition.notchViewModelController.state.sessionPreviews.isEmpty {
            await Task.yield()
        }

        _ = try client.send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "codex",
            requestId: nil,
            command: .updateJumpTarget,
            payload: [
                "sessionId": .string("completed-session"),
                "jumpInput": .object([
                    "bundleId": .string("com.apple.Terminal"),
                    "tty": .string("ttys903"),
                ]),
            ]
        ))
        for _ in 0..<20 where composition.notchViewModelController.state.sessions.first?.jumpInput == nil {
            await Task.yield()
        }
        XCTAssertEqual(
            composition.notchViewModelController.state.sessions.first?.jumpInput?.tty,
            "ttys903"
        )

        _ = try client.send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("UserPromptSubmit"),
                "sessionId": .string("completed-session"),
                "cwd": .string("/tmp/live-project"),
                "prompt": .string("Finish the requested work"),
            ]
        ))

        _ = try client.send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("Stop"),
                "sessionId": .string("completed-session"),
                "cwd": .string("/tmp/live-project"),
                "message": .string("Finished the requested work"),
            ]
        ))
        for _ in 0..<40 where composition.notificationCoordinatorController.lastPlan == nil {
            await Task.yield()
        }

        XCTAssertEqual(
            composition.notchViewModelController.state.notificationPreviews.map(\.sessionId),
            ["completed-session"]
        )
        XCTAssertEqual(
            composition.notchViewModelController.state.overlayState.panelState.presentationState.displayState,
            .expanded
        )
        XCTAssertEqual(
            composition.notificationCoordinatorController.lastPlan?.notification.body,
            "Finished the requested work"
        )
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .notificationCoordinator),
            .unavailable("notification coordinator is owned by AppKit composition")
        )
    }

    @MainActor
    func testProductionRuntimeObserverRendersCompactOriginalSurfaceForExternalSessionStart() async throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            notchPanelController: notchPanelController,
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 0,
                    frameWidth: 1920,
                    auxiliaryTopLeftWidth: 0,
                    auxiliaryTopRightWidth: 0,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1050)
                )
            }
        )

        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])
        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("external-session"),
                "cwd": .string("/tmp/external-project"),
            ]
        ))

        for _ in 0..<100 where notchPanelController.lastContentView == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let host = try XCTUnwrap(originalCompactHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 206, height: 30))
        XCTAssertEqual(host.rootView.layoutMode, .compact)
    }

    @MainActor
    func testProductionPermissionActionResolvesBlockingLocalHook() async throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let panelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            notchPanelController: panelController
        )
        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])
        let responseBox = BridgeResponseBox()
        let hookFinished = expectation(description: "blocking permission hook finished")
        DispatchQueue.global().async {
            do {
                responseBox.record(.success(try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "hook",
                    source: "codex",
                    requestId: "permission-1",
                    command: .hookEvent,
                    payload: [
                        "hook_event_name": .string("PermissionRequest"),
                        "session_id": .string("session-1"),
                        "cwd": .string("/tmp/project"),
                        "tool_name": .string("Shell"),
                        "prompt": .string("Allow shell command?"),
                    ]
                ))))
            } catch {
                responseBox.record(.failure(error))
            }
            hookFinished.fulfill()
        }

        for _ in 0..<100 where composition.notchViewModelController.state.actionRequestPreviews.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(panelController.lastContentView)
        let preview = try XCTUnwrap(composition.notchViewModelController.state.actionRequestPreviews.first)
        XCTAssertTrue(preview.canResolveLocally)

        XCTAssertTrue(runtime.resolveAction(ActionResolution(
            requestId: preview.requestId,
            sessionId: preview.sessionId,
            kind: .approve
        )))
        await fulfillment(of: [hookFinished], timeout: 1.0)

        XCTAssertEqual(try responseBox.response().sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(["behavior": .string("allow")]),
            ]),
        ]))
    }

    @MainActor
    func testProductionOpenCodeQuestionWizardResolvesBlockingLocalHook() async throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer { runtime.stop() }
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let panelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            notchPanelController: panelController
        )
        _ = composition.platformIntentExecutor.execute([.startRuntimeOwner(.bridgeServer)])
        let responseBox = BridgeResponseBox()
        let hookFinished = expectation(description: "blocking OpenCode question hook finished")
        DispatchQueue.global().async {
            do {
                responseBox.record(.success(try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "hook",
                    source: "opencode",
                    requestId: "question-1",
                    command: .hookEvent,
                    payload: [
                        "rawEventName": .string("PermissionRequest"),
                        "sessionId": .string("session-1"),
                        "cwd": .string("/tmp/project"),
                        "toolName": .string("AskUserQuestion"),
                        "tool_input": .object([
                            "questions": .array([
                                .object([
                                    "header": .string("Target"),
                                    "question": .string("Where should this run?"),
                                    "options": .array([
                                        .object(["label": .string("Local")]),
                                        .object(["label": .string("Remote")]),
                                    ]),
                                    "multiSelect": .bool(false),
                                ]),
                                .object([
                                    "header": .string("Checks"),
                                    "question": .string("Which checks should run?"),
                                    "options": .array([
                                        .object(["label": .string("Tests")]),
                                        .object(["label": .string("Lint")]),
                                    ]),
                                    "multiSelect": .bool(true),
                                ]),
                            ]),
                        ]),
                    ]
                ))))
            } catch {
                responseBox.record(.failure(error))
            }
            hookFinished.fulfill()
        }

        for _ in 0..<100 where composition.notchViewModelController.state.actionRequestPreviews.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(panelController.lastContentView)
        let preview = try XCTUnwrap(composition.notchViewModelController.state.actionRequestPreviews.first)
        XCTAssertTrue(preview.canResolveLocally)
        XCTAssertTrue(runtime.resolveAction(ActionResolution(
            requestId: preview.requestId,
            sessionId: preview.sessionId,
            kind: .answer,
            answers: [
                "Target": "Local",
                "Checks": "Tests, Lint",
            ]
        )))
        await fulfillment(of: [hookFinished], timeout: 1.0)

        XCTAssertEqual(try responseBox.response().sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([
                        "answers": .object([
                            "Target": .string("Local"),
                            "Checks": .string("Tests, Lint"),
                        ]),
                    ]),
                ]),
            ]),
        ]))
    }

    @MainActor
    func testProductionCompositionUsesPersistedSoundManagerForBothPlanningPaths() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let preferences = SoundPreferencesStore(defaults: defaults)
        preferences.saveManagerSettings(SoundManagerSettings(volume: 0.4))
        preferences.saveSourceSelections(SoundSourceStoreSnapshot(selections: [
            SoundSourceSelection(
                category: .permission,
                sourceKind: .builtin8bit,
                soundId: "builtin8bit.permission",
                isEnabled: true,
                volume: 0.5,
                cooldownSeconds: 3,
                outputRouteBehavior: "default"
            ),
        ]))
        var plans: [SoundManagerPlaybackPlan] = []
        let playbackController = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { plans.append($0) },
            recordSuppressedSound: { plans.append($0) }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            defaults: defaults,
            soundPlaybackController: playbackController
        )

        composition.notificationPresentationController.requestSound(NotificationSoundRequest(
            notificationId: "permission-1",
            category: .permission,
            source: "codex"
        ))
        _ = composition.soundCoordinatorController.handle(SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans.map(\.effectiveVolume), [0.2, 0.2])
        XCTAssertEqual(plans.map(\.cooldownSeconds), [3, 3])
    }

    @MainActor
    func testPlatformCompositionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            PlatformCompositionMatrixFixture.self,
            from: try AppFixtureLoader.data("app/platform-composition-matrix")
        )
        var events: [String] = []
        let lifecycleController = MyVibeIslandAppKitLifecycleController(
            applyStep: { events.append("step:\($0.rawValue)") },
            ignoreMenuCommand: { events.append("ignored:\($0)") }
        )
        let runtimeOwnerController = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { events.append("start:\($0.rawValue)") },
            stopOwner: { events.append("stop:\($0.rawValue)") }
        )
        let routeController = MyVibeIslandAppKitRouteController(
            activateApplication: { events.append("activate") },
            showWindow: { events.append("window:\($0)") },
            quitApplication: { events.append("quit") }
        )
        let systemCommandController = MyVibeIslandAppKitSystemCommandController(
            setDockIconVisible: { events.append("dock:\($0)") },
            setLaunchAtLoginEnabled: { events.append("login:\($0)") },
            checkForUpdates: { events.append("updates") },
            exportDiagnostics: { events.append("diagnostics") }
        )
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { events.append("panel:create"); return "panel" },
            installEventMonitors: { events.append("panel:install") },
            removeEventMonitors: { events.append("panel:remove") },
            movePanel: { _, frame in events.append("panel:move:\(Int(frame.width))x\(Int(frame.height))") },
            installContentView: { _, _ in },
            showPanel: { _ in events.append("panel:show") },
            hidePanel: { _ in events.append("panel:hide") },
            closePanel: { _ in events.append("panel:close") }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            lifecycleController: lifecycleController,
            runtimeOwnerController: runtimeOwnerController,
            systemCommandController: systemCommandController,
            routeController: routeController,
            notchPanelController: notchPanelController,
            selectSession: { events.append("select:\($0)") },
            jumpToSession: { events.append("jump:\($0)") },
            resolveAction: { events.append("resolve:\($0):\($1)") },
            answerQuestion: { events.append("answer:\($0):\($1)") }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 0, width: 640, height: 420),
            anchor: DisplayPoint(x: 120, y: 20),
            safeAreaAdjustment: 20
        )
        let result = composition.platformIntentExecutor.execute([
            .lifecycle(.createRuntime),
            .startRuntimeOwner(.bridgeServer),
            .startRuntimeOwner(.sessionCoordinator),
            .createNotchPanel,
            .installNotchEventMonitors,
            .applyTargetScreen("built-in"),
            .applyNotchPlacement(placement),
            .showNotchPanel,
            .showIsland,
            .openSettings(SettingsDeepLink(section: .integrations, rowId: "codex")),
            .showOnboarding,
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(true),
            .checkForUpdates,
            .exportDiagnostics,
            .ignoredMenuCommand(.exportDiagnostics),
            .overlay(.routeAction(.selectSession(sessionId: "session-1"))),
            .overlay(.routeAction(.jumpToSession(sessionId: "session-2"))),
            .overlay(.routeAction(.resolveAction(requestId: "request-1", sessionId: "session-3"))),
            .overlay(.routeAction(.answerQuestion(requestId: "request-2", sessionId: "session-4"))),
            .stopRuntimeOwner(.bridgeServer),
            .hideNotchPanel,
            .removeNotchEventMonitors,
            .closeNotchPanel,
            .quitApplication
        ])
        let actual = PlatformCompositionMatrixFixture(rows: [
            PlatformCompositionMatrixRow(
                id: "injected-platform-routing",
                executedIntentCount: result.executedIntents.count,
                lifecycleSteps: lifecycleController.appliedSteps.map(\.rawValue),
                ignoredCommands: lifecycleController.ignoredMenuCommands.map(String.init(describing:)),
                runningOwners: runtimeOwnerController.runningOwners.map(\.rawValue),
                targetScreenIdentifier: notchPanelController.targetScreenIdentifier,
                hasPanel: notchPanelController.panel != nil,
                panelVisible: notchPanelController.isVisible,
                dockIconVisible: systemCommandController.dockIconVisible,
                launchAtLoginEnabled: systemCommandController.launchAtLoginEnabled,
                maintenanceCommands: systemCommandController.maintenanceCommands.map(String.init(describing:)),
                hasLastOverlayRoute: composition.overlayController.lastRoutedAction != nil,
                events: events
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testCompositionInstallsStatusMenuIntoStatusItemAndRoutesMenuCommands() throws {
        var commands: [AppCommand] = []
        let statusItem = NSStatusItem()
        let composition = MyVibeIslandAppKitPlatformComposition(
            statusItemController: MyVibeIslandAppKitStatusItemController(
                createStatusItem: { statusItem },
                removeStatusItem: { _ in }
            ),
            dispatchMenuCommand: { command in
                commands.append(command)
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

        let result = composition.platformIntentExecutor.execute([
            .applyStatusItemMenu(snapshot)
        ])

        XCTAssertEqual(result.executedIntents, [.applyStatusItemMenu(snapshot)])
        let menu = try XCTUnwrap(statusItem.menu)
        XCTAssertEqual(menu.items[0].identifier?.rawValue, "openSettings")

        let router = try XCTUnwrap(menu.items[0].target as? MyVibeIslandAppKitStatusMenuCommandRouter)
        router.performStatusMenuCommand(menu.items[0])

        XCTAssertEqual(commands, [.openSettings])
    }

    @MainActor
    func testCompositionCanRouteMenuCommandsThroughShellDispatcher() throws {
        let statusItem = NSStatusItem()
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let shellDispatcher = MyVibeIslandAppKitShellCommandDispatcher(
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
        let composition = MyVibeIslandAppKitPlatformComposition(
            statusItemController: MyVibeIslandAppKitStatusItemController(
                createStatusItem: { statusItem },
                removeStatusItem: { _ in }
            ),
            shellCommandDispatcher: shellDispatcher
        )

        _ = composition.platformIntentExecutor.execute([
            .applyStatusItemMenu(launchPlan.statusItemMenu)
        ])
        let menu = try XCTUnwrap(statusItem.menu)
        let openSettingsItem = try XCTUnwrap(
            menu.items.first { $0.identifier?.rawValue == "openSettings" }
        )
        let router = try XCTUnwrap(openSettingsItem.target as? MyVibeIslandAppKitStatusMenuCommandRouter)

        router.performStatusMenuCommand(openSettingsItem)

        XCTAssertEqual(events, ["overlay", "settings"])
    }

    @MainActor
    func testCompositionRoutesPlatformRouteIntentsThroughRouteController() {
        var events: [String] = []
        let routeController = MyVibeIslandAppKitRouteController(
            activateApplication: {
                events.append("activate")
            },
            showWindow: { window in
                events.append("window:\(window)")
            },
            quitApplication: {
                events.append("quit")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            routeController: routeController
        )

        _ = composition.platformIntentExecutor.execute([
            .showIsland,
            .openSettings(nil),
            .showOnboarding,
            .quitApplication
        ])

        XCTAssertEqual(events, [
            "activate",
            "window:settings:general",
            "quit"
        ])
    }

    @MainActor
    func testCompositionRoutesOnboardingIntentThroughOnboardingWindowControllerByDefault() {
        let onboardingWindowController = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { NSRect(x: 0, y: 0, width: 1440, height: 900) }
        )
        defer { onboardingWindowController.close() }
        let composition = MyVibeIslandAppKitPlatformComposition(
            onboardingWindowController: onboardingWindowController
        )

        _ = composition.platformIntentExecutor.execute([
            .showOnboarding
        ])

        XCTAssertNotNil(onboardingWindowController.fullscreenWindow)
        XCTAssertNil(onboardingWindowController.cardWindow)
        XCTAssertNil(onboardingWindowController.readyWindow)
    }

    @MainActor
    func testProductionOnboardingPersistsNotificationSoundSelection() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let onboardingWindowController = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { NSRect(x: 0, y: 0, width: 1440, height: 900) }
        )
        defer { onboardingWindowController.close() }
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        _ = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            onboardingWindowController: onboardingWindowController
        )
        onboardingWindowController.show()
        onboardingWindowController.completeFullscreen()

        onboardingWindowController.completeCard(selection: MyVibeIslandOnboardingSelection(
            playNotificationSounds: false
        ))

        XCTAssertFalse(SoundPreferencesStore(defaults: defaults).loadManagerSettings().isEnabled)
    }

    @MainActor
    func testProductionSystemDiagnosticCommandBuildsReadyPlan() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([.exportDiagnostics])

        XCTAssertEqual(composition.diagnosticExportController.lastPlan?.status, .ready)
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .diagnosticsCoordinator),
            .unavailable("diagnostics coordinator is owned by AppKit composition")
        )
    }

    @MainActor
    func testProductionUsageControllerLoadsSettingsAndPublishesPresentationToNotch() async throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let expected = UsageSettingsSnapshot(
            preferredProviderId: .codexRateLimits,
            displayStyle: .ringBadge
        )
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: { SettingsSnapshot(usage: expected) }
        )

        let presentation = await composition.usageCoordinatorController.presentationSnapshot(
            refreshPlanNowSeconds: 100
        )

        XCTAssertEqual(composition.usageCoordinatorController.settings, expected)
        XCTAssertEqual(composition.notchViewModelController.state.usagePresentation, presentation)
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .usageCoordinator),
            .unavailable("usage coordinator is owned by AppKit composition")
        )
    }

    @MainActor
    func testProductionPublishesInitialLocalUsagePresentation() async throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: {
                SettingsSnapshot(usage: UsageSettingsSnapshot(displayStyle: .ringBadge))
            }
        )
        for _ in 0..<40 where composition.notchViewModelController.state.usagePresentation == nil {
            await Task.yield()
        }

        XCTAssertNotNil(composition.usageCoordinatorController.lastPresentationSnapshot)
        XCTAssertEqual(
            composition.notchViewModelController.state.usagePresentation,
            composition.usageCoordinatorController.lastPresentationSnapshot
        )
    }

    @MainActor
    func testProductionMigratesEnabledUsagePreferenceWhenPersistedUsageIsHidden() async throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        defaults.set(true, forKey: "showUsage")
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            settingsSnapshotProvider: { SettingsSnapshot() }
        )

        for _ in 0..<40 where composition.notchViewModelController.state.usagePresentation == nil {
            await Task.yield()
        }

        XCTAssertEqual(composition.usageCoordinatorController.settings.displayStyle, .ringBadge)
        XCTAssertEqual(
            composition.notchViewModelController.state.usagePresentation?.displayState.status,
            .unavailable
        )
    }

    @MainActor
    func testProductionUpdateCommandIsExplicitlyUnavailableWithoutRequest() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitPlatformCompositionTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            defaults: defaults,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController()
        )

        _ = composition.platformIntentExecutor.execute([.checkForUpdates])

        XCTAssertEqual(composition.updateCheckerController.lastPlan?.action, .updatesUnavailable)
        XCTAssertNil(composition.updateCheckerController.lastPlan?.request)
        XCTAssertEqual(
            composition.runtimeOwnerController.availability(of: .updateCoordinator),
            .unavailable("updates are not configured in this noncommercial build")
        )
    }

    @MainActor
    func testCompositionRoutesNotchPanelIntentsThroughNotchPanelController() async throws {
        var events: [String] = []
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                events.append("create")
                return "panel"
            },
            installEventMonitors: {
                events.append("install")
            },
            removeEventMonitors: {
                events.append("remove")
            },
            movePanel: { panel, frame in
                events.append("move:\(panel):\(Int(frame.width))")
            },
            installContentView: { _, _ in },
            showPanel: { panel in
                events.append("show:\(panel)")
            },
            hidePanel: { panel in
                events.append("hide:\(panel)")
            },
            closePanel: { panel in
                events.append("close:\(panel)")
            }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 0, width: 220, height: 36),
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            notchPanelController: notchPanelController
        )

        _ = composition.platformIntentExecutor.execute([
            .createNotchPanel,
            .installNotchEventMonitors,
            .applyTargetScreen("built-in"),
            .applyNotchPlacement(placement),
            .showNotchPanel
        ])
        try await Task.sleep(nanoseconds: 80_000_000)
        _ = composition.platformIntentExecutor.execute([
            .hideNotchPanel,
            .removeNotchEventMonitors,
            .closeNotchPanel
        ])

        XCTAssertEqual(notchPanelController.targetScreenIdentifier, "built-in")
        XCTAssertEqual(events, [
            "create",
            "install",
            "show:panel",
            "move:panel:220",
            "hide:panel",
            "remove",
            "close:panel"
        ])
    }

    @MainActor
    func testProductionScreenInputCapturePropagatesFrameAndVisibleFrame() {
        let input = appKitOriginalCompactHostingScreenInput(
            safeAreaTopInset: 0,
            frame: NSRect(x: -1920, y: 120, width: 1920, height: 1080),
            visibleFrame: NSRect(x: -1920, y: 120, width: 1920, height: 1050),
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0
        )

        XCTAssertEqual(input.frameWidth, 1920)
        XCTAssertEqual(
            input.screenFrame,
            DisplayFrame(x: -1920, y: 120, width: 1920, height: 1080)
        )
        XCTAssertEqual(
            input.visibleFrame,
            DisplayFrame(x: -1920, y: 120, width: 1920, height: 1050)
        )
    }

    @MainActor
    func testScreenSnapshotNormalizationIncludesCapturedMainCandidateForMainFallback() {
        let listed = OriginalCompactHostingScreenCandidate(
            identifier: "listed",
            input: OriginalNSScreenMetricsInput(
                safeAreaTopInset: 0,
                frameWidth: 1920,
                auxiliaryTopLeftWidth: 0,
                auxiliaryTopRightWidth: 0
            )
        )
        let main = OriginalCompactHostingScreenCandidate(
            identifier: "main",
            input: OriginalNSScreenMetricsInput(
                safeAreaTopInset: 32,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: 663,
                auxiliaryTopRightWidth: 664
            )
        )

        let snapshot = appKitOriginalCompactHostingScreenSnapshot(
            candidates: [listed],
            mainCandidate: main
        )
        let resolved = OriginalCompactHostingScreenSelection.resolve(
            candidates: snapshot.candidates,
            selectedIdentifier: nil,
            mainIdentifier: snapshot.mainIdentifier,
            fallback: listed.input
        )

        XCTAssertEqual(snapshot.candidates, [listed, main])
        XCTAssertEqual(snapshot.mainIdentifier, "main")
        XCTAssertEqual(resolved, main.input)
    }

    @MainActor
    func testScreenSnapshotNormalizationDoesNotDuplicateCapturedMainCandidate() {
        let main = OriginalCompactHostingScreenCandidate(
            identifier: "main",
            input: OriginalNSScreenMetricsInput(
                safeAreaTopInset: 32,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: 663,
                auxiliaryTopRightWidth: 664
            )
        )

        let snapshot = appKitOriginalCompactHostingScreenSnapshot(
            candidates: [main],
            mainCandidate: main
        )

        XCTAssertEqual(snapshot.candidates, [main])
        XCTAssertEqual(snapshot.mainIdentifier, "main")
    }

    @MainActor
    func testProductionCompositionHostsAcceptedPhysicalCompactInFixedClearPanel() async throws {
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let orderedScreens = [
            ScreenDescriptor(
                identifier: "ordered-first",
                displayName: "Ordered First",
                isBuiltIn: false,
                hasNotch: false,
                isMain: false
            ),
            ScreenDescriptor(
                identifier: "appkit-main",
                displayName: "AppKit Main",
                isBuiltIn: true,
                hasNotch: true,
                isMain: true
            )
        ]
        let screenSelectionController = MyVibeIslandAppKitScreenSelectionController(
            snapshot: ScreenSelectionSnapshot(mode: .mainDisplay),
            currentScreens: { orderedScreens }
        )
        let selectedScreen = OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 950)
        )
        var resolvedScreenIdentifiers: [String?] = []
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            notchPanelController: notchPanelController,
            screenSelectionController: screenSelectionController,
            originalCompactHostingScreenResolver: { selectedIdentifier in
                resolvedScreenIdentifiers.append(selectedIdentifier)
                return selectedScreen
            }
        )
        XCTAssertEqual(screenSelectionController.snapshot.target?.identifier, "ordered-first")
        let fixedFrame = DisplayFrame(x: 416, y: 402, width: 680, height: 580)
        let placement = DisplayPlacementPlan(
            closedFrame: fixedFrame,
            expandedFrame: fixedFrame,
            anchor: DisplayPoint(x: 756, y: 982),
            safeAreaAdjustment: 32
        )

        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            originalStatus: .processing,
            repoName: "project"
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill],
            displayStatus: .closed,
            layoutMode: .compact,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            contentSize: DisplaySize(width: 264, height: 36)
        ))

        _ = composition.platformIntentExecutor.execute([
            .applyNotchPlacement(placement),
            .overlay(.renderIslandSurface(renderList)),
        ])
        try await Task.sleep(nanoseconds: 80_000_000)

        let host = try XCTUnwrap(originalCompactHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(
            DisplaySize(width: placement.closedFrame.width, height: placement.closedFrame.height),
            DisplaySize(width: 680, height: 580)
        )
        XCTAssertEqual(
            DisplaySize(width: placement.expandedFrame.width, height: placement.expandedFrame.height),
            DisplaySize(width: 680, height: 580)
        )
        XCTAssertEqual(notchPanelController.lastFrame, placement.closedFrame)
        XCTAssertEqual(host.frame.size, NSSize(width: 680, height: 580))
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 239, height: 32))
        XCTAssertEqual(resolvedScreenIdentifiers, ["ordered-first"])
        XCTAssertTrue(host.wantsLayer)
        XCTAssertEqual(host.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertGreaterThan(host.frame.width, host.rootView.surfaceSize.width)
        XCTAssertGreaterThan(host.frame.height, host.rootView.surfaceSize.height)
    }

    @MainActor
    func testProductionCompositionRoutesExpandedStateThroughNewTypedHost() throws {
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            runtime: runtime,
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            notchPanelController: notchPanelController,
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 32,
                    frameWidth: 1512,
                    auxiliaryTopLeftWidth: 663,
                    auxiliaryTopRightWidth: 664,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 947)
                )
            }
        )
        let sessions = (0..<3).map { index in
            AgentSession(
                id: "expanded-\(index)",
                source: "codex",
                cwd: "/work/project-\(index)",
                originalStatus: .processing,
                repoName: "project-\(index)"
            )
        }
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions.first?.id,
            contentSize: DisplaySize(width: 680, height: 580)
        ))

        _ = composition.platformIntentExecutor.execute([
            .overlay(.renderIslandSurface(renderList)),
        ])

        let host = try XCTUnwrap(originalExpandedHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(host.frame.size, NSSize(width: 680, height: 580))
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 640, height: 270))
    }

    func testProductionUnifiedRendererRoutesHeaderSettingsThroughOverlayAction() throws {
        let source = try String(contentsOf: platformCompositionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("onOpenSettings: { routeOverlayAction(.openSettings) }"))
        XCTAssertTrue(source.contains("SoundPreferencesStore(defaults: defaults).loadManagerSnapshot()"))
        XCTAssertTrue(source.contains("planSound: { request in"))
    }

    @MainActor
    func testCompositionRoutesOverlayIntentsThroughOverlayController() {
        var events: [String] = []
        let overlayController = MyVibeIslandAppKitOverlayController(
            renderPresentation: { presentation in
                events.append("render:\(presentation.displayState.rawValue)")
            },
            applyFrame: { frame in
                events.append("frame:\(Int(frame.width))")
            },
            showPanel: { displayState in
                events.append("show:\(displayState.rawValue)")
            },
            hidePanel: { reason in
                events.append("hide:\(reason.rawValue)")
            },
            forwardInteractionAction: { _ in
                events.append("interaction")
            },
            routeAction: { _ in
                events.append("route")
            },
            recordDisplayReason: { reason in
                events.append("reason:\(reason.rawValue)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            overlayController: overlayController
        )
        let presentation = NotchPresentationState(displayState: .expanded)

        _ = composition.platformIntentExecutor.execute([
            .overlay(.renderPresentation(presentation)),
            .overlay(.routeAction(.openSettings))
        ])

        XCTAssertEqual(overlayController.lastPresentation, presentation)
        XCTAssertEqual(overlayController.lastRoutedAction, .openSettings)
        XCTAssertEqual(events, [
            "render:expanded",
            "route"
        ])
    }

    @MainActor
    func testCompositionRoutesExternalClosedThroughOriginalTypedHost() throws {
        var events: [String] = []
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                events.append("create")
                return "panel"
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { panel, view in
                let route = originalCompactHost(in: view) == nil ? "legacy" : "original"
                events.append("content:\(panel):\(route)")
            },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 0,
                    frameWidth: 1920,
                    auxiliaryTopLeftWidth: 0,
                    auxiliaryTopRightWidth: 0,
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1050)
                )
            },
            notchPanelController: notchPanelController
        )
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill],
            displayStatus: .closed,
            layoutMode: .compact,
            primarySessionIds: ["active"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 320, height: 120)
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(sections: sections)))
        ])

        XCTAssertEqual(events, [
            "create",
            "content:panel:original"
        ])
        let host = try XCTUnwrap(originalCompactHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(host.frame.size, NSSize(width: 680, height: 580))
        XCTAssertEqual(host.rootView.displayClass, .nonNotched)
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 206, height: 30))
    }

    @MainActor
    func testProductionNoScreenFallbackDoesNotRouteThroughOriginalTypedHost() {
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController(),
            notchPanelController: notchPanelController,
            originalCompactHostingScreenResolver: { _ in
                OriginalNSScreenMetricsInput(
                    safeAreaTopInset: 0,
                    frameWidth: 0,
                    auxiliaryTopLeftWidth: 0,
                    auxiliaryTopRightWidth: 0
                )
            }
        )
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill],
            displayStatus: .closed,
            layoutMode: .compact,
            primarySessionIds: ["active"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 320, height: 120)
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.renderIslandSurface(IslandSurfaceRenderList(sections: sections)))
        ])

        XCTAssertNil(originalCompactHost(in: notchPanelController.lastContentView))
        XCTAssertEqual(
            notchPanelController.lastContentView?.identifier?.rawValue,
            "my-vibe-island.surface"
        )
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayPanelVisibilityToNotchPanelBoundary() {
        var events: [String] = []
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                events.append("create")
                return "panel"
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { panel in
                events.append("show:\(panel)")
            },
            hidePanel: { panel in
                events.append("hide:\(panel)")
            },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            notchPanelController: notchPanelController
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.applyPanelPlan(actions: [
                .showPanel(displayState: .expanded),
                .hidePanel(reason: .outsideClick)
            ]))
        ])

        XCTAssertEqual(events, [
            "create",
            "show:panel",
            "hide:panel"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayPanelFrameToNotchPanelBoundary() async throws {
        var events: [String] = []
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                events.append("create")
                return "panel"
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { panel, frame in
                events.append("move:\(panel):\(Int(frame.width))x\(Int(frame.height))")
            },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            notchPanelController: notchPanelController
        )
        let frame = DisplayFrame(x: 10, y: 20, width: 640, height: 420)

        _ = composition.platformIntentExecutor.execute([
            .overlay(.applyPanelPlan(actions: [
                .applyFrame(frame)
            ]))
        ])
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(events, [
            "create",
            "move:panel:640x420"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayInteractionActionsToNotchPanelBoundary() {
        let notchPanelController = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                "panel"
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            notchPanelController: notchPanelController
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.applyPanelPlan(actions: [
                .forwardInteractionAction(.requestKeyboardFocus)
            ]))
        ])

        XCTAssertEqual(notchPanelController.lastInteractionAction, .requestKeyboardFocus)
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayOpenSettingsActionThroughRouteBoundary() {
        var events: [String] = []
        let routeController = MyVibeIslandAppKitRouteController(
            activateApplication: {
                events.append("activate")
            },
            showWindow: { window in
                events.append("window:\(window)")
            },
            quitApplication: {}
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            routeController: routeController
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.openSettings))
        ])

        XCTAssertEqual(composition.overlayController.lastRoutedAction, .openSettings)
        XCTAssertEqual(events, [
            "window:settings:general"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayOpenSettingsThroughShellDispatcherWhenPresent() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let shellDispatcher = MyVibeIslandAppKitShellCommandDispatcher(
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
        let composition = MyVibeIslandAppKitPlatformComposition(
            shellCommandDispatcher: shellDispatcher
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.openSettings))
        ])

        XCTAssertEqual(composition.overlayController.lastRoutedAction, .openSettings)
        XCTAssertEqual(events, [
            "overlay",
            "settings"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayJumpThroughShellDispatcherWhenPresent() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let shellDispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            jumpToSession: { sessionId in
                events.append("jump:\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            shellCommandDispatcher: shellDispatcher
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.jumpToSession(sessionId: "session-1")))
        ])

        XCTAssertEqual(composition.overlayController.lastRoutedAction, .jumpToSession(sessionId: "session-1"))
        XCTAssertEqual(events, ["jump:session-1"])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlaySelectThroughShellDispatcherWhenPresent() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let shellDispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            selectSession: { sessionId in
                events.append("select:\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            shellCommandDispatcher: shellDispatcher
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.selectSession(sessionId: "session-1")))
        ])

        XCTAssertEqual(composition.overlayController.lastRoutedAction, .selectSession(sessionId: "session-1"))
        XCTAssertEqual(events, ["select:session-1"])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayResolutionActionsThroughShellDispatcherWhenPresent() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        var events: [String] = []
        let shellDispatcher = MyVibeIslandAppKitShellCommandDispatcher(
            initialState: launchPlan.coordinatorPlan.nextState,
            resolveAction: { requestId, sessionId in
                events.append("resolve:\(requestId):\(sessionId)")
            },
            answerQuestion: { requestId, sessionId in
                events.append("answer:\(requestId):\(sessionId)")
            },
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor()
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            shellCommandDispatcher: shellDispatcher
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.resolveAction(requestId: "request-1", sessionId: "session-1"))),
            .overlay(.routeAction(.answerQuestion(requestId: "request-2", sessionId: "session-2")))
        ])

        XCTAssertEqual(
            composition.overlayController.lastRoutedAction,
            .answerQuestion(requestId: "request-2", sessionId: "session-2")
        )
        XCTAssertEqual(events, [
            "resolve:request-1:session-1",
            "answer:request-2:session-2"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlaySessionActionsThroughInjectedBoundariesWithoutShellDispatcher() {
        var events: [String] = []
        let composition = MyVibeIslandAppKitPlatformComposition(
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
            }
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.selectSession(sessionId: "session-1"))),
            .overlay(.routeAction(.jumpToSession(sessionId: "session-2"))),
            .overlay(.routeAction(.resolveAction(requestId: "request-1", sessionId: "session-3"))),
            .overlay(.routeAction(.answerQuestion(requestId: "request-2", sessionId: "session-4")))
        ])

        XCTAssertEqual(
            composition.overlayController.lastRoutedAction,
            .answerQuestion(requestId: "request-2", sessionId: "session-4")
        )
        XCTAssertEqual(events, [
            "select:session-1",
            "jump:session-2",
            "resolve:request-1:session-3",
            "answer:request-2:session-4"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultOverlayAppCommandThroughCommandBoundary() {
        var commands: [AppCommand] = []
        let composition = MyVibeIslandAppKitPlatformComposition(
            dispatchMenuCommand: { command in
                commands.append(command)
            }
        )

        _ = composition.platformIntentExecutor.execute([
            .overlay(.routeAction(.appCommand(.openSettings)))
        ])

        XCTAssertEqual(composition.overlayController.lastRoutedAction, .appCommand(.openSettings))
        XCTAssertEqual(commands, [.openSettings])
    }

    @MainActor
    func testCompositionRoutesLifecycleRuntimeAndIgnoredMenuIntentsThroughControllers() {
        var events: [String] = []
        let lifecycleController = MyVibeIslandAppKitLifecycleController(
            applyStep: { step in
                events.append("step:\(step.rawValue)")
            },
            ignoreMenuCommand: { command in
                events.append("ignored:\(command)")
            }
        )
        let runtimeOwnerController = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { owner in
                events.append("start:\(owner.rawValue)")
            },
            stopOwner: { owner in
                events.append("stop:\(owner.rawValue)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            lifecycleController: lifecycleController,
            runtimeOwnerController: runtimeOwnerController
        )

        _ = composition.platformIntentExecutor.execute([
            .lifecycle(.createRuntime),
            .startRuntimeOwner(.bridgeServer),
            .startRuntimeOwner(.sessionCoordinator),
            .ignoredMenuCommand(.exportDiagnostics),
            .stopRuntimeOwner(.bridgeServer)
        ])

        XCTAssertEqual(lifecycleController.appliedSteps, [.createRuntime])
        XCTAssertEqual(lifecycleController.ignoredMenuCommands, [.exportDiagnostics])
        XCTAssertEqual(runtimeOwnerController.runningOwners, [.sessionCoordinator])
        XCTAssertEqual(events, [
            "step:createRuntime",
            "start:bridgeServer",
            "start:sessionCoordinator",
            "ignored:exportDiagnostics",
            "stop:bridgeServer"
        ])
    }

    @MainActor
    func testCompositionRoutesSystemCommandIntentsThroughController() {
        var events: [String] = []
        let systemCommandController = MyVibeIslandAppKitSystemCommandController(
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
        let composition = MyVibeIslandAppKitPlatformComposition(
            systemCommandController: systemCommandController
        )

        _ = composition.platformIntentExecutor.execute([
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(true),
            .checkForUpdates,
            .exportDiagnostics
        ])

        XCTAssertEqual(systemCommandController.dockIconVisible, true)
        XCTAssertEqual(systemCommandController.launchAtLoginEnabled, true)
        XCTAssertEqual(systemCommandController.maintenanceCommands, [.checkForUpdates, .exportDiagnostics])
        XCTAssertEqual(events, [
            "dock:true",
            "login:true",
            "updates",
            "diagnostics"
        ])
    }

    @MainActor
    func testCompositionRoutesCheckForUpdatesThroughUpdateWindowControllerByDefault() {
        var events: [String] = []
        let updateWindowController = MyVibeIslandAppKitUpdateWindowController(
            snapshot: UpdatePresentationSnapshot(currentVersion: "1.0.0"),
            presentWindow: { viewModel in
                events.append("update:\(viewModel.snapshot.phase.rawValue)")
            },
            dismissWindow: {}
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            updateWindowController: updateWindowController
        )

        _ = composition.platformIntentExecutor.execute([
            .checkForUpdates
        ])

        XCTAssertEqual(updateWindowController.snapshot.phase, .checking)
        XCTAssertEqual(events, ["update:checking"])
    }

    @MainActor
    func testCompositionRoutesCheckForUpdatesThroughUpdateCheckerControllerByDefault() {
        var events: [String] = []
        let updateCheckerController = MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: "1.0.0",
            presentManualCheck: {
                events.append("present")
            },
            performCheck: { request in
                events.append("check:\(request.kind.rawValue):\(request.currentVersion)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            updateCheckerController: updateCheckerController
        )

        _ = composition.platformIntentExecutor.execute([
            .checkForUpdates
        ])

        XCTAssertEqual(updateCheckerController.lastPlan?.action, .startManualCheck)
        XCTAssertEqual(events, [
            "present",
            "check:manual:1.0.0"
        ])
    }

    @MainActor
    func testCompositionRoutesExportDiagnosticsThroughDiagnosticExportControllerByDefault() {
        var events: [String] = []
        let diagnosticExportController = MyVibeIslandAppKitDiagnosticExportController(
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["appVersion"],
                        forbiddenFields: [],
                        fields: ["appVersion": "1.0"]
                    )
                ]
            },
            publishPlan: { plan in
                events.append("diagnostics:\(plan.status.rawValue)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            diagnosticExportController: diagnosticExportController
        )

        _ = composition.platformIntentExecutor.execute([
            .exportDiagnostics
        ])

        XCTAssertEqual(diagnosticExportController.lastPlan?.status, .failedClosed)
        XCTAssertEqual(events, ["diagnostics:failedClosed"])
    }

    @MainActor
    func testCompositionRoutesDockAndLaunchAtLoginThroughDedicatedControllersByDefault() {
        var events: [String] = []
        let dockIconController = MyVibeIslandAppKitDockIconController(
            applyActivationPolicy: { policy in
                events.append("dock:\(policy.rawValue)")
            }
        )
        let launchAtLoginController = MyVibeIslandAppKitLaunchAtLoginController(
            applyDesiredEnabled: { isEnabled in
                events.append("login:\(isEnabled)")
            },
            publishRepairHint: { _ in }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            dockIconController: dockIconController,
            launchAtLoginController: launchAtLoginController
        )

        _ = composition.platformIntentExecutor.execute([
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(true)
        ])

        XCTAssertTrue(dockIconController.state.preferredDockVisible)
        XCTAssertTrue(launchAtLoginController.state.desiredEnabled)
        XCTAssertEqual(events, [
            "dock:regular",
            "login:true"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultNotificationDeliveryThroughPresentationAndSoundBoundaries() {
        var events: [String] = []
        let soundPlaybackController = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { plan in
                events.append("play:\(plan.category.rawValue):\(plan.soundId ?? "none")")
            },
            recordSuppressedSound: { plan in
                events.append("suppress:\(plan.category.rawValue)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            soundPlaybackController: soundPlaybackController,
            notificationSoundMinuteOfDay: { 12 * 60 }
        )
        let notification = PeekNotification(
            id: "permission-1",
            category: .permissionRequested,
            sessionId: "session-1",
            agent: "codex",
            title: "Permission requested",
            body: "Codex wants to edit a file",
            severity: .blocking,
            createdAt: "2026-07-09T00:00:00Z",
            dwellSeconds: 8,
            soundCategory: .permission,
            source: "codex"
        )

        let plan = composition.notificationCoordinatorController.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent
            )
        )

        XCTAssertTrue(plan.publishPeek)
        XCTAssertEqual(composition.notificationPresentationController.lastAction, .requestSound(NotificationSoundRequest(
            notificationId: "permission-1",
            category: .permission,
            source: "codex"
        )))
        XCTAssertEqual(soundPlaybackController.lastAction, .play(SoundManagerPlaybackPlan(
            action: .playBuiltin8bit,
            category: .permission,
            sourceKind: .builtin8bit,
            soundId: "builtin8bit.permission",
            effectiveVolume: 1,
            cooldownSeconds: 0
        )))
        XCTAssertEqual(events, [
            "play:permission:builtin8bit.permission"
        ])
    }

    @MainActor
    func testCompositionRoutesDefaultSoundCoordinatorThroughPlaybackBoundary() throws {
        var events: [String] = []
        let soundPlaybackController = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { plan in
                events.append("play:\(plan.category.rawValue):\(plan.soundId ?? "none")")
            },
            recordSuppressedSound: { plan in
                events.append("suppress:\(plan.category.rawValue)")
            }
        )
        let composition = MyVibeIslandAppKitPlatformComposition(
            soundPlaybackController: soundPlaybackController
        )

        let plan = composition.soundCoordinatorController.handle(SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plan.action, .playSound)
        XCTAssertEqual(soundPlaybackController.lastAction, .play(try XCTUnwrap(plan.playbackPlan)))
        XCTAssertEqual(events, [
            "play:permission:builtin8bit.permission"
        ])
    }

    func testSwitcherShortcutEntryDoesNotReuseTransientRevealTimer() throws {
        let source = try String(contentsOf: platformCompositionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(".transientReveal(reason: .switcher)"))
        XCTAssertEqual(
            source.components(separatedBy: "switcherPanelInteractionRouter.perform(.openSwitcher)").count - 1,
            2
        )
    }

    @MainActor
    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    private var platformCompositionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitPlatformComposition.swift")
    }
}

@MainActor
private func originalCompactHost(
    in container: NSView?
) -> NSHostingView<OriginalUnifiedIslandRootView>? {
    guard let container, container.subviews.count == 1 else { return nil }
    guard let host = container.subviews[0] as? NSHostingView<OriginalUnifiedIslandRootView>,
          host.rootView.model.presentation.displayState == .compact else { return nil }
    return host
}

@MainActor
private func originalExpandedHost(
    in container: NSView?
) -> NSHostingView<OriginalUnifiedIslandRootView>? {
    guard let container, container.subviews.count == 1 else { return nil }
    guard let host = container.subviews[0] as? NSHostingView<OriginalUnifiedIslandRootView>,
          host.rootView.model.presentation.displayState == .expanded else { return nil }
    return host
}

private struct PlatformCompositionMatrixFixture: Codable, Equatable {
    let rows: [PlatformCompositionMatrixRow]
}

private struct PlatformCompositionMatrixRow: Codable, Equatable {
    let id: String
    let executedIntentCount: Int
    let lifecycleSteps: [String]
    let ignoredCommands: [String]
    let runningOwners: [String]
    let targetScreenIdentifier: String?
    let hasPanel: Bool
    let panelVisible: Bool
    let dockIconVisible: Bool
    let launchAtLoginEnabled: Bool
    let maintenanceCommands: [String]
    let hasLastOverlayRoute: Bool
    let events: [String]
}
