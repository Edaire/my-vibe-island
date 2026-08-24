import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
private final class MutableMouseLocation {
    var value: DisplayPoint

    init(_ value: DisplayPoint) {
        self.value = value
    }
}

final class MyVibeIslandAppKitNotchPanelControllerTests: XCTestCase {
    @MainActor
    func testIdleAutoHideKeepsPanelVisibleWhilePointerIsInMenuBarZone() {
        var hiddenPanels: [String] = []
        var interactions: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { DisplayPoint(x: 50, y: 466) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { panel in hiddenPanels.append(panel) },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 450, width: 100, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 50, y: 450),
            safeAreaAdjustment: 0
        )

        controller.applyPlacement(placement)
        controller.processMouseLocation(DisplayPoint(x: 50, y: 466))
        XCTAssertTrue(interactions.contains(.setMouseInMenuBarZone(true)))
        controller.setIdleHidden(true)

        XCTAssertEqual(hiddenPanels, [])
    }

    @MainActor
    func testIdleAutoHideFadesOnlyAfterPointerLeavesMenuBarZone() {
        let currentMouseLocation = MutableMouseLocation(DisplayPoint(x: 50, y: 466))
        var hiddenPanels: [String] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { currentMouseLocation.value },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { panel in hiddenPanels.append(panel) },
            closePanel: { _ in }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 450, width: 100, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 50, y: 450),
            safeAreaAdjustment: 0
        )

        controller.applyPlacement(placement)
        controller.processMouseLocation(currentMouseLocation.value)
        controller.setIdleHidden(true)
        currentMouseLocation.value = DisplayPoint(x: 300, y: 300)
        controller.processMouseLocation(currentMouseLocation.value)

        XCTAssertEqual(hiddenPanels, ["panel"])
    }

    @MainActor
    func testIdleAutoHideDoesNotRepeatTheSamePanelHiddenTarget() {
        var hiddenPanels: [String] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { panel in hiddenPanels.append(panel) },
            closePanel: { _ in }
        )

        controller.setIdleHidden(true)
        controller.setIdleHidden(true)

        XCTAssertEqual(hiddenPanels, ["panel"])
    }

    func testProductionPanelVisibilityUsesRecoveredAppKitFadeParameters() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchPanelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("duration: 0.16"))
        XCTAssertTrue(source.contains("timingFunction: .easeIn"))
        XCTAssertTrue(source.contains("duration: 0.12"))
        XCTAssertTrue(source.contains("timingFunction: .easeOut"))
        XCTAssertTrue(source.contains("panel.ignoresMouseEvents = true"))
        XCTAssertTrue(source.contains("panel.animator().alphaValue = targetAlpha"))
    }

    func testProductionIdleAutoHideKeepsPanelVisibilityIndependentOfDisplayState() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchPanelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("func setIdleHidden(_ isHidden: Bool)"))
        XCTAssertTrue(source.contains("hidePanel(panel)"))
        XCTAssertTrue(source.contains("showPanel(panel)"))
        XCTAssertFalse(source.contains("interactionDisplayState = .autoHidden"))
    }

    func testProductionMouseMonitorMatchesOriginalMoveAndLeftDragEventMasks() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchPanelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged])"))
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged])"))
        XCTAssertFalse(source.contains("pointerSamplingTimer"))
        XCTAssertFalse(source.contains("Timer(timeInterval:"))
    }

    func testProductionHoverPipelineLogsPointerBoundaryAndAutoCollapseTick() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitNotchPanelController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("hover.pointer_state"))
        XCTAssertTrue(source.contains("hover.auto_collapse_tick"))
    }

    @MainActor
    func testExpandedSurfaceEnablesClicksWhileTransparentHostAreaStaysClickThrough() {
        var ignoresMouseEvents: [Bool] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { DisplayPoint(x: 220, y: 450) },
            setIgnoresMouseEvents: { _, value in ignoresMouseEvents.append(value) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )

        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 220, y: 900),
            safeAreaAdjustment: 0
        ))
        controller.processMouseLocation(DisplayPoint(x: 220, y: 916))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.processMouseLocation(DisplayPoint(x: 700, y: 700))
        controller.applyInteractionAction(.collapsePanel(reason: .outsideClick))

        XCTAssertEqual(ignoresMouseEvents, [true, false, true, true])
    }

    @MainActor
    func testExpandedGeometryChangeRecomputesClickThroughForStationaryPointer() {
        var ignoresMouseEvents: [Bool] = []
        let currentMouseLocation = MutableMouseLocation(DisplayPoint(x: 220, y: 450))
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { currentMouseLocation.value },
            setIgnoresMouseEvents: { _, value in ignoresMouseEvents.append(value) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 220, y: 900),
            safeAreaAdjustment: 0
        ))
        controller.processMouseLocation(DisplayPoint(x: 220, y: 916))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        currentMouseLocation.value = DisplayPoint(x: 700, y: 700)

        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 100, height: 80)
        ))

        XCTAssertEqual(ignoresMouseEvents, [true, false, true])
    }

    @MainActor
    func testExpandedGeometryChangeReclassifiesStationaryPointerForLeaveLifecycle() {
        var interactions: [PanelInteractionCommand] = []
        let currentMouseLocation = MutableMouseLocation(DisplayPoint(x: 220, y: 450))
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { currentMouseLocation.value },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 220, y: 900),
            safeAreaAdjustment: 0
        ))
        controller.processMouseLocation(DisplayPoint(x: 220, y: 916))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        interactions.removeAll()
        currentMouseLocation.value = DisplayPoint(x: 700, y: 700)

        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 100, height: 80)
        ))

        XCTAssertEqual(interactions, [.setExpandedPanelHover(false)])
    }

    @MainActor
    func testGeometryReclassificationUsesCurrentPointerInsteadOfLastDeliveredEvent() {
        var interactions: [PanelInteractionCommand] = []
        let currentMouseLocation = MutableMouseLocation(DisplayPoint(x: 50, y: 466))
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { currentMouseLocation.value },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 450, width: 100, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 50, y: 450),
            safeAreaAdjustment: 0
        )
        controller.applyPlacement(placement)
        controller.processMouseLocation(DisplayPoint(x: 50, y: 466))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        interactions.removeAll()
        currentMouseLocation.value = DisplayPoint(x: 700, y: 700)

        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: placement.closedFrame,
            expandedFrame: placement.expandedFrame
        ))

        XCTAssertEqual(interactions, [.setExpandedPanelHover(false)])
    }

    @MainActor
    func testExpandedStateChangeReclassifiesCurrentPointerForLeaveLifecycle() {
        var interactions: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { DisplayPoint(x: 700, y: 700) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 450, width: 100, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 50, y: 450),
            safeAreaAdjustment: 0
        )
        controller.applyPlacement(placement)
        controller.processMouseLocation(DisplayPoint(x: 50, y: 466))
        interactions.removeAll()

        controller.applyInteractionAction(.setDisplayState(.expanded))

        XCTAssertEqual(interactions, [.setExpandedPanelHover(false)])
    }

    @MainActor
    func testExpandedContentHoverExitUsesTheSameLeaveLifecycleWithoutGlobalMouseEvent() {
        var interactions: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )

        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.processExpandedContentHover(true)
        interactions.removeAll()

        controller.processExpandedContentHover(false)

        XCTAssertEqual(interactions, [.setExpandedPanelHover(false)])
    }

    @MainActor
    func testFrameApplicationReclassifiesAgainstCurrentPointer() async throws {
        var interactions: [PanelInteractionCommand] = []
        let currentMouseLocation = MutableMouseLocation(DisplayPoint(x: 50, y: 466))
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { currentMouseLocation.value },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { interactions.append($0) }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 450, width: 100, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 50, y: 450),
            safeAreaAdjustment: 0
        )
        controller.applyPlacement(placement)
        controller.processMouseLocation(DisplayPoint(x: 50, y: 466))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        interactions.removeAll()
        currentMouseLocation.value = DisplayPoint(x: 700, y: 700)

        controller.applyFrame(placement.expandedFrame)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(interactions, [.setExpandedPanelHover(false)])
    }

    @MainActor
    func testClearInteractionGeometryRemovesRetainedUnifiedRendererFrames() {
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 1, y: 2, width: 3, height: 4),
            expandedFrame: DisplayFrame(x: 5, y: 6, width: 7, height: 8)
        ))

        controller.clearInteractionGeometry()

        XCTAssertNil(controller.interactionGeometry)
    }
    @MainActor
    func testProductionPanelUsesFrozenWindowLevelConfiguration() throws {
        let controller = MyVibeIslandAppKitNotchPanelController<NSPanel>()

        controller.createPanel()

        let panel = try XCTUnwrap(controller.panel)
        XCTAssertEqual(panel.styleMask.rawValue, 128)
        XCTAssertEqual(panel.level, NSWindow.Level(rawValue: 27))
        XCTAssertEqual(panel.collectionBehavior.rawValue, 337)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertEqual(panel.titleVisibility.rawValue, 1)
        XCTAssertTrue(panel.titlebarAppearsTransparent)
        XCTAssertTrue(panel.allowsToolTipsWhenApplicationIsInactive)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.acceptsMouseMovedEvents)
        XCTAssertFalse(panel.isMovable)
        XCTAssertEqual(panel.animationBehavior.rawValue, 2)
        XCTAssertFalse(panel.isReleasedWhenClosed)
    }

    @MainActor
    func testNotchPanelDoesNotConstrainFramesBelowTheMenuBar() {
        let panel = MyVibeIslandAppKitNotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let requested = NSRect(x: 624, y: 946, width: 264, height: 36)

        XCTAssertEqual(panel.constrainFrameRect(requested, to: NSScreen.main), requested)
    }

    @MainActor
    func testProductionPanelFramesSnapToBackingPixelsForSharperText() {
        let frame = DisplayFrame(x: 624.25, y: 946.25, width: 264.25, height: 36.25)

        XCTAssertEqual(
            MyVibeIslandAppKitNotchPanelController<NSPanel>.pixelAlignedFrame(frame, scale: 2),
            DisplayFrame(x: 624.5, y: 946.5, width: 264.5, height: 36.5)
        )
    }

    @MainActor
    func testNotchPanelControllerMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            NotchPanelControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/notch-panel-controller-matrix")
        )
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { events.append("create"); return "panel-1" },
            installEventMonitors: { events.append("install-monitors") },
            removeEventMonitors: { events.append("remove-monitors") },
            movePanel: { events.append("move:\($0):\(Int($1.width))") },
            installContentView: { events.append("content:\($0):\($1.identifier?.rawValue ?? "missing")") },
            showPanel: { events.append("show:\($0)") },
            hidePanel: { events.append("hide:\($0)") },
            closePanel: { events.append("close:\($0)") }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 0, width: 640, height: 420),
            anchor: DisplayPoint(x: 120, y: 20),
            safeAreaAdjustment: 20
        )
        let contentView = NSView()
        contentView.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.surface")
        controller.createPanel()
        controller.installMonitors()
        controller.applyTargetScreen("built-in")
        controller.applyPlacement(placement)
        try await Task.sleep(nanoseconds: 80_000_000)
        controller.installContentView(contentView)
        controller.show()
        controller.applyInteractionAction(.requestKeyboardFocus)
        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3))
        controller.applyInteractionAction(.scheduleAutoCollapse(delay: 4, generation: 5))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.applyInteractionAction(.collapsePanel(reason: .outsideClick))
        controller.hide()
        controller.removeMonitors()
        controller.close()
        let actual = NotchPanelControllerMatrixFixture(rows: [
            NotchPanelControllerMatrixRow(
                id: "injected-panel-lifecycle",
                hasPanel: controller.panel != nil,
                targetScreenIdentifier: controller.targetScreenIdentifier,
                placementClosedWidth: controller.lastPlacement?.closedFrame.width,
                lastFrameWidth: controller.lastFrame?.width,
                contentViewIdentifier: controller.lastContentView?.identifier?.rawValue,
                hasLastInteractionAction: controller.lastInteractionAction != nil,
                keyboardFocusRequested: controller.keyboardFocusRequested,
                pendingHoverReveal: controller.pendingHoverReveal != nil,
                pendingAutoCollapse: controller.pendingAutoCollapse != nil,
                interactionDisplayState: controller.interactionDisplayState.rawValue,
                hasCollapseReason: controller.lastCollapseReason != nil,
                isVisible: controller.isVisible,
                events: events
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppliesNotchPanelOperationsThroughInjectedClosures() async throws {
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                events.append("create")
                return "panel-1"
            },
            installEventMonitors: {
                events.append("install-monitors")
            },
            removeEventMonitors: {
                events.append("remove-monitors")
            },
            movePanel: { panel, frame in
                events.append("move:\(panel):\(Int(frame.width))")
            },
            installContentView: { panel, view in
                events.append("content:\(panel):\(view.identifier?.rawValue ?? "missing")")
            },
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
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 0, width: 640, height: 420),
            anchor: DisplayPoint(x: 120, y: 20),
            safeAreaAdjustment: 20
        )

        controller.createPanel()
        controller.installMonitors()
        controller.applyTargetScreen("built-in")
        controller.applyPlacement(placement)
        try await Task.sleep(nanoseconds: 80_000_000)
        let contentView = NSView()
        contentView.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.surface")
        controller.installContentView(contentView)
        controller.show()
        controller.hide()
        controller.removeMonitors()
        controller.close()

        XCTAssertEqual(controller.panel, nil)
        XCTAssertEqual(controller.lastContentView, contentView)
        XCTAssertEqual(controller.targetScreenIdentifier, "built-in")
        XCTAssertEqual(controller.lastPlacement, placement)
        XCTAssertEqual(events, [
            "create",
            "install-monitors",
            "move:panel-1:220",
            "content:panel-1:my-vibe-island.surface",
            "show:panel-1",
            "hide:panel-1",
            "remove-monitors",
            "close:panel-1"
        ])
    }

    @MainActor
    func testInstallingContentViewDoesNotReapplyTheFixedPanelFrame() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let expandedFrame = DisplayFrame(x: 416, y: 630, width: 680, height: 320)

        controller.applyFrame(expandedFrame)
        controller.installContentView(NSView())
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(movedFrames, [expandedFrame])
    }

    @MainActor
    func testInstallingTheRetainedContentViewDoesNotReplaceThePanelContentAgain() {
        var installationCount = 0
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in installationCount += 1 },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let retainedHost = NSView()

        controller.installContentView(retainedHost)
        controller.installContentView(retainedHost)

        XCTAssertEqual(installationCount, 1)
        XCTAssertTrue(controller.lastContentView === retainedHost)
    }

    @MainActor
    func testApplyingTheSameFixedPanelFrameDoesNotMoveThePanelAgain() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let fixedFrame = DisplayFrame(x: 416, y: 402, width: 680, height: 580)

        controller.applyFrame(fixedFrame)
        controller.applyFrame(fixedFrame)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(movedFrames, [fixedFrame])
    }

    @MainActor
    func testPlacementRefreshPreservesExpandedPanelFrame() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let initial = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 900, width: 240, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 420),
            anchor: DisplayPoint(x: 130, y: 900),
            safeAreaAdjustment: 0
        )
        let refreshed = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 20, y: 880, width: 240, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 360, width: 640, height: 460),
            anchor: DisplayPoint(x: 140, y: 880),
            safeAreaAdjustment: 0
        )

        controller.applyPlacement(initial)
        try await Task.sleep(nanoseconds: 80_000_000)
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.applyPlacement(refreshed)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(movedFrames, [initial.closedFrame, refreshed.expandedFrame])
        XCTAssertEqual(controller.lastFrame, refreshed.expandedFrame)
    }

    @MainActor
    func testFrameUpdatesCoalesceAfterOriginalFiftyMillisecondTaskDelay() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let compact = DisplayFrame(x: 500, y: 900, width: 240, height: 36)
        let expanded = DisplayFrame(x: 300, y: 400, width: 640, height: 420)

        controller.applyFrame(compact)
        controller.applyFrame(expanded)

        XCTAssertEqual(movedFrames, [])
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(movedFrames, [])
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(movedFrames, [expanded])
        XCTAssertEqual(controller.lastFrame, expanded)
    }

    @MainActor
    func testPendingExpansionCannotOverwriteAnImmediateCollapseBackToCommittedCompactFrame() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let compact = DisplayFrame(x: 620, y: 966, width: 680, height: 114)
        let expanded = DisplayFrame(x: 620, y: 500, width: 680, height: 580)

        controller.applyFrame(compact)
        try await Task.sleep(nanoseconds: 80_000_000)
        controller.applyFrame(expanded)
        controller.applyFrame(compact)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(movedFrames, [compact])
        XCTAssertEqual(controller.lastFrame, compact)
    }

    @MainActor
    func testHidingPanelDoesNotCancelOriginalPendingWindowFrameTask() async throws {
        var movedFrames: [DisplayFrame] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, frame in movedFrames.append(frame) },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let frame = DisplayFrame(x: 300, y: 400, width: 640, height: 420)

        controller.applyFrame(frame)
        controller.hide()
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(movedFrames, [frame])
    }

    @MainActor
    func testShowingPanelEnsuresMouseMonitoringIsInstalledExactlyOnce() {
        var monitoringStarts = 0
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            startMouseMonitoring: { _ in monitoringStarts += 1 },
            stopMouseMonitoring: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )

        controller.show()
        XCTAssertEqual(monitoringStarts, 1)

        controller.show()
        controller.installMonitors()

        XCTAssertEqual(monitoringStarts, 1)
    }

    @MainActor
    func testControllerCreatesPanelLazilyForPlacementAndReusesIt() {
        var createCount = 0
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: {
                createCount += 1
                return "panel-\(createCount)"
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 0, width: 180, height: 40),
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0
        )

        controller.applyPlacement(placement)
        controller.show()

        XCTAssertEqual(createCount, 1)
        XCTAssertEqual(controller.panel, "panel-1")
    }

    @MainActor
    func testControllerRoutesMouseMovementThroughCompactAndExpandedHoverZones() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            anchor: DisplayPoint(x: 232, y: 936),
            safeAreaAdjustment: 32
        ))
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 100, y: 900, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 700, width: 680, height: 220)
        ))

        controller.processMouseLocation(DisplayPoint(x: 20, y: 800))
        controller.processMouseLocation(DisplayPoint(x: 200, y: 920))
        controller.processMouseLocation(DisplayPoint(x: 20, y: 800))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.processMouseLocation(DisplayPoint(x: 200, y: 800))
        controller.processMouseLocation(DisplayPoint(x: 900, y: 500))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMouseInMenuBarZone(true),
            .setMenuBarHover(false),
            .setMouseInMenuBarZone(false),
            .setExpandedPanelHover(true),
            .setExpandedPanelHover(false),
        ])
    }

    @MainActor
    func testWiderMenuBarZoneTriggersHoverBeforeThePointerReachesCompactContent() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            anchor: DisplayPoint(x: 340, y: 980),
            safeAreaAdjustment: 0
        ))
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 200, y: 944, width: 280, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 700, width: 680, height: 220)
        ))

        controller.processMouseLocation(DisplayPoint(x: 170, y: 960))
        controller.processMouseLocation(DisplayPoint(x: 220, y: 960))
        controller.processMouseLocation(DisplayPoint(x: 170, y: 960))
        controller.processMouseLocation(DisplayPoint(x: 100, y: 960))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMouseInMenuBarZone(true),
            .setMenuBarHover(false),
            .setMouseInMenuBarZone(false),
        ])
    }

    @MainActor
    func testCompactHoverIncludesTheVisibleSixPointHoverShadow() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            anchor: DisplayPoint(x: 340, y: 980),
            safeAreaAdjustment: 0
        ))
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 200, y: 944, width: 280, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 700, width: 680, height: 220)
        ))

        controller.processMouseLocation(DisplayPoint(x: 220, y: 940))
        controller.processMouseLocation(DisplayPoint(x: 220, y: 936))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMenuBarHover(false),
        ])
    }

    @MainActor
    func testAllExpandedPlacementDisplayStatesRouteMouseThroughExpandedFrame() {
        for displayState in [
            PanelDisplayState.notificationPeek,
            .switcher,
            .onboarding,
        ] {
            var commands: [PanelInteractionCommand] = []
            let controller = MyVibeIslandAppKitNotchPanelController(
                makePanel: { "panel" },
                installEventMonitors: {},
                removeEventMonitors: {},
                movePanel: { _, _ in },
                installContentView: { _, _ in },
                showPanel: { _ in },
                hidePanel: { _ in },
                closePanel: { _ in },
                performInteraction: { commands.append($0) }
            )
            controller.applyPlacement(DisplayPlacementPlan(
                closedFrame: DisplayFrame(x: 0, y: 0, width: 100, height: 20),
                expandedFrame: DisplayFrame(x: 200, y: 200, width: 400, height: 300),
                anchor: DisplayPoint(x: 0, y: 0),
                safeAreaAdjustment: 0
            ))
            controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
                compactFrame: DisplayFrame(x: 0, y: 0, width: 100, height: 20),
                expandedFrame: DisplayFrame(x: 200, y: 200, width: 400, height: 300)
            ))
            controller.applyInteractionAction(.setDisplayState(displayState))
            controller.processMouseLocation(DisplayPoint(x: 300, y: 300))

            XCTAssertEqual(commands, [.setExpandedPanelHover(true)], "state=\(displayState)")
        }
    }

    @MainActor
    func testHoverExpansionCarriesPointerIntoExpandedPanelForLeaveDetection() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { DisplayPoint(x: 200, y: 800) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            anchor: DisplayPoint(x: 232, y: 936),
            safeAreaAdjustment: 32
        ))
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 100, y: 900, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 700, width: 680, height: 220)
        ))

        controller.processMouseLocation(DisplayPoint(x: 200, y: 920))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.processMouseLocation(DisplayPoint(x: 900, y: 500))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMouseInMenuBarZone(true),
            .setExpandedPanelHover(true),
            .setExpandedPanelHover(false),
        ])
    }

    @MainActor
    func testCompletionExpansionReportsPanelEnterAndLeaveAfterMenuBarHover() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            currentMouseLocation: { DisplayPoint(x: 200, y: 800) },
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 680, height: 580),
            anchor: DisplayPoint(x: 232, y: 936),
            safeAreaAdjustment: 32
        ))
        controller.applyInteractionGeometry(MyVibeIslandAppKitPanelInteractionGeometry(
            compactFrame: DisplayFrame(x: 100, y: 900, width: 264, height: 36),
            expandedFrame: DisplayFrame(x: 0, y: 700, width: 680, height: 220)
        ))

        controller.processMouseLocation(DisplayPoint(x: 200, y: 920))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.processMouseLocation(DisplayPoint(x: 200, y: 800))
        controller.processMouseLocation(DisplayPoint(x: 900, y: 500))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMouseInMenuBarZone(true),
            .setExpandedPanelHover(true),
            .setExpandedPanelHover(false),
        ])
    }

    @MainActor
    func testControllerTracksPanelVisibilityState() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        XCTAssertFalse(controller.isVisible)

        controller.show()

        XCTAssertTrue(controller.isVisible)

        controller.hide()

        XCTAssertFalse(controller.isVisible)

        controller.show()
        controller.close()

        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    func testShowingAnAlreadyVisibleFixedPanelDoesNotOrderItFrontAgain() {
        var showCount = 0
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in showCount += 1 },
            hidePanel: { _ in },
            closePanel: { _ in }
        )

        controller.show()
        controller.show()

        XCTAssertEqual(showCount, 1)
    }

    @MainActor
    func testControllerTracksKeyboardFocusInteractionIntent() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        XCTAssertFalse(controller.keyboardFocusRequested)

        controller.applyInteractionAction(.requestKeyboardFocus)

        XCTAssertTrue(controller.keyboardFocusRequested)
        XCTAssertEqual(controller.lastInteractionAction, .requestKeyboardFocus)

        controller.applyInteractionAction(.releaseKeyboardFocus)

        XCTAssertFalse(controller.keyboardFocusRequested)
        XCTAssertEqual(controller.lastInteractionAction, .releaseKeyboardFocus)
    }

    @MainActor
    func testControllerTracksTimerInteractionIntentsWithoutSchedulingTimers() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3))
        controller.applyInteractionAction(.scheduleAutoCollapse(delay: 4.0, generation: 5))
        controller.applyInteractionAction(.scheduleMouseLeaveCollapse(delay: 0.25, generation: 7))

        XCTAssertEqual(
            controller.pendingHoverReveal,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 0.2, generation: 3)
        )
        XCTAssertEqual(
            controller.pendingAutoCollapse,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 4.0, generation: 5)
        )
        XCTAssertEqual(
            controller.pendingMouseLeaveCollapse,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 0.25, generation: 7)
        )

        controller.applyInteractionAction(.cancelMouseLeaveCollapse)

        XCTAssertEqual(
            controller.pendingHoverReveal,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 0.2, generation: 3)
        )
        XCTAssertEqual(
            controller.pendingAutoCollapse,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 4.0, generation: 5)
        )
        XCTAssertNil(controller.pendingMouseLeaveCollapse)
        XCTAssertEqual(controller.lastInteractionAction, .cancelMouseLeaveCollapse)
    }

    @MainActor
    func testControllerCancelsPendingHoverRevealTaskAndIntent() {
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in }
        )

        controller.applyInteractionAction(.scheduleHoverReveal(delay: 4, generation: 1))
        XCTAssertNotNil(controller.pendingHoverReveal)

        controller.applyInteractionAction(.cancelHoverReveal)

        XCTAssertNil(controller.pendingHoverReveal)
        XCTAssertEqual(controller.lastInteractionAction, .cancelHoverReveal)
    }

    @MainActor
    func testZeroDelayHoverRevealFiresSynchronouslyWithoutScheduling() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )

        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0, generation: 7))

        XCTAssertEqual(commands, [.hoverRevealTick(generation: 7)])
        XCTAssertNil(controller.pendingHoverReveal)
    }

    @MainActor
    func testRemoveMonitorsCancelsPendingTimersAndPreventsCallbacks() async throws {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            stopMouseMonitoring: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )

        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.02, generation: 1))
        controller.applyInteractionAction(.scheduleAutoCollapse(delay: 0.02, generation: 1))
        controller.removeMonitors()
        try await Task.sleep(for: .milliseconds(60))

        XCTAssertTrue(commands.isEmpty)
        XCTAssertNil(controller.pendingHoverReveal)
        XCTAssertNil(controller.pendingAutoCollapse)
    }

    @MainActor
    func testTimerCallbackClearsMatchingIntentBeforeForwardingTick() async throws {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )

        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.01, generation: 4))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(commands, [.hoverRevealTick(generation: 4)])
        XCTAssertNil(controller.pendingHoverReveal)
    }

    @MainActor
    func testMouseEventProcessingFiresDueHoverRevealWhenMainActorTaskIsDelayed() {
        var commands: [PanelInteractionCommand] = []
        let controller = MyVibeIslandAppKitNotchPanelController(
            makePanel: { "panel" },
            installEventMonitors: {},
            removeEventMonitors: {},
            movePanel: { _, _ in },
            installContentView: { _, _ in },
            showPanel: { _ in },
            hidePanel: { _ in },
            closePanel: { _ in },
            performInteraction: { commands.append($0) }
        )
        controller.applyPlacement(DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 900, width: 240, height: 32),
            expandedFrame: DisplayFrame(x: 0, y: 400, width: 640, height: 120),
            anchor: DisplayPoint(x: 220, y: 916),
            safeAreaAdjustment: 0
        ))
        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.01, generation: 4))
        Thread.sleep(forTimeInterval: 0.02)

        controller.processMouseLocation(DisplayPoint(x: 220, y: 916))

        XCTAssertEqual(commands, [
            .setMenuBarHover(true),
            .setMouseInMenuBarZone(true),
            .hoverRevealTick(generation: 4),
        ])
        XCTAssertNil(controller.pendingHoverReveal)
    }

    @MainActor
    func testControllerTracksDisplayStateAndCollapseInteractionIntent() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        XCTAssertEqual(controller.interactionDisplayState, .closed)
        XCTAssertNil(controller.lastCollapseReason)

        controller.applyInteractionAction(.setDisplayState(.expanded))

        XCTAssertEqual(controller.interactionDisplayState, .expanded)
        XCTAssertNil(controller.lastCollapseReason)

        controller.applyInteractionAction(.collapsePanel(reason: .outsideClick))

        XCTAssertEqual(controller.interactionDisplayState, .closed)
        XCTAssertEqual(controller.lastCollapseReason, .outsideClick)
        XCTAssertEqual(controller.lastInteractionAction, .collapsePanel(reason: .outsideClick))
    }

    @MainActor
    func testControllerCloseClearsPendingInteractionIntentState() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        controller.show()
        controller.applyInteractionAction(.requestKeyboardFocus)
        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3))
        controller.applyInteractionAction(.scheduleAutoCollapse(delay: 4.0, generation: 5))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.applyInteractionAction(.collapsePanel(reason: .outsideClick))

        controller.close()

        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(controller.keyboardFocusRequested)
        XCTAssertNil(controller.pendingHoverReveal)
        XCTAssertNil(controller.pendingAutoCollapse)
        XCTAssertEqual(controller.interactionDisplayState, .closed)
        XCTAssertNil(controller.lastCollapseReason)
        XCTAssertNil(controller.lastInteractionAction)
    }

    @MainActor
    func testControllerHideClearsPendingInteractionIntentState() {
        let controller = MyVibeIslandAppKitNotchPanelController(
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

        controller.show()
        controller.applyInteractionAction(.requestKeyboardFocus)
        controller.applyInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3))
        controller.applyInteractionAction(.scheduleAutoCollapse(delay: 4.0, generation: 5))
        controller.applyInteractionAction(.setDisplayState(.expanded))
        controller.applyInteractionAction(.collapsePanel(reason: .keyboardShortcut))

        controller.hide()

        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(controller.keyboardFocusRequested)
        XCTAssertNil(controller.pendingHoverReveal)
        XCTAssertNil(controller.pendingAutoCollapse)
        XCTAssertEqual(controller.interactionDisplayState, .closed)
        XCTAssertNil(controller.lastCollapseReason)
        XCTAssertNil(controller.lastInteractionAction)
    }
}

private struct NotchPanelControllerMatrixFixture: Codable, Equatable {
    let rows: [NotchPanelControllerMatrixRow]
}

private struct NotchPanelControllerMatrixRow: Codable, Equatable {
    let id: String
    let hasPanel: Bool
    let targetScreenIdentifier: String?
    let placementClosedWidth: Double?
    let lastFrameWidth: Double?
    let contentViewIdentifier: String?
    let hasLastInteractionAction: Bool
    let keyboardFocusRequested: Bool
    let pendingHoverReveal: Bool
    let pendingAutoCollapse: Bool
    let interactionDisplayState: String
    let hasCollapseReason: Bool
    let isVisible: Bool
    let events: [String]
}
