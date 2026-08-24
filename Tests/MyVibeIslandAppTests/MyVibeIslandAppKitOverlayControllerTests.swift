import MyVibeIslandCore
import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitOverlayControllerTests: XCTestCase {
    @MainActor
    func testOverlayControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OverlayControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/overlay-controller-matrix")
        )
        var events: [String] = []
        let controller = MyVibeIslandAppKitOverlayController(
            renderPresentation: { events.append("render:\($0.displayState.rawValue)") },
            renderIslandSurface: { events.append("surface:\($0.items.count)") },
            buildIslandSurfaceView: {
                events.append("build:\(Int($0.contentSize.width))x\(Int($0.contentSize.height))")
                return NSView(frame: NSRect(x: 0, y: 0, width: $0.contentSize.width, height: $0.contentSize.height))
            },
            renderIslandSurfaceView: { events.append("view:\(Int($0.frame.width))") },
            applyFrame: { events.append("frame:\(Int($0.width))") },
            showPanel: { events.append("show:\($0.rawValue)") },
            hidePanel: { events.append("hide:\($0.rawValue)") },
            forwardInteractionAction: { _ in events.append("interaction") },
            routeAction: { _ in events.append("route") },
            recordDisplayReason: { events.append("reason:\($0.rawValue)") }
        )
        controller.apply(.renderPresentation(NotchPresentationState(displayState: .expanded)))
        controller.apply(.applyPanelPlan(actions: [
            .applyFrame(DisplayFrame(x: 0, y: 0, width: 640, height: 420)),
            .showPanel(displayState: .expanded),
            .forwardInteractionAction(.requestKeyboardFocus),
            .forwardInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3)),
            .forwardInteractionAction(.scheduleAutoCollapse(delay: 4, generation: 5)),
            .forwardInteractionAction(.cancelAutoCollapse),
            .hidePanel(reason: .outsideClick),
            .recordDisplayReason(.outsideClick)
        ]))
        controller.apply(.routeAction(.appCommand(.openSettings)))
        controller.apply(.recordDisplayReason(.keyboardShortcut))
        controller.renderIslandSurface(IslandSurfaceRenderList(sections: IslandSurfaceSections(
            visibleSections: [.compactPill],
            primarySessionIds: ["active"],
            contentSize: DisplaySize(width: 320, height: 120)
        )))

        let actual = OverlayControllerMatrixFixture(rows: [
            OverlayControllerMatrixRow(id: "injected-overlay-flow", controller: controller, events: events)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppliesOverlayActionsThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitOverlayController(
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
            forwardInteractionAction: { action in
                events.append("interaction:\(action)")
            },
            routeAction: { action in
                events.append("route:\(action)")
            },
            recordDisplayReason: { reason in
                events.append("reason:\(reason.rawValue)")
            }
        )
        let presentation = NotchPresentationState(displayState: .expanded)
        let frame = DisplayFrame(x: 0, y: 0, width: 640, height: 420)

        controller.apply(.renderPresentation(presentation))
        controller.apply(.applyPanelPlan(actions: [
            .applyFrame(frame),
            .showPanel(displayState: .expanded),
            .forwardInteractionAction(.requestKeyboardFocus),
            .hidePanel(reason: .outsideClick),
            .recordDisplayReason(.outsideClick)
        ]))
        controller.apply(.routeAction(.appCommand(.openSettings)))
        controller.apply(.recordDisplayReason(.keyboardShortcut))

        XCTAssertEqual(controller.lastPresentation, presentation)
        XCTAssertEqual(controller.lastAppliedFrame, frame)
        XCTAssertEqual(controller.lastShownPanelState, .expanded)
        XCTAssertEqual(controller.lastHiddenPanelReason, .outsideClick)
        XCTAssertNil(controller.lastForwardedInteractionAction)
        XCTAssertEqual(controller.currentPanelDisplayState, .closed)
        XCTAssertEqual(events, [
            "render:expanded",
            "frame:640",
            "show:expanded",
            "interaction:requestKeyboardFocus",
            "hide:outsideClick",
            "reason:outsideClick",
            "route:appCommand(MyVibeIslandCore.AppCommand.openSettings)",
            "reason:keyboardShortcut"
        ])
    }

    @MainActor
    func testControllerTracksDisplayStateFromForwardedInteractionActions() {
        let controller = MyVibeIslandAppKitOverlayController()

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.setDisplayState(.opening)),
            .forwardInteractionAction(.setDisplayState(.expanded))
        ]))

        XCTAssertEqual(controller.currentPanelDisplayState, .expanded)

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.collapsePanel(reason: .keyboardShortcut))
        ]))

        XCTAssertEqual(controller.currentPanelDisplayState, .closed)
        XCTAssertEqual(
            controller.lastForwardedInteractionAction,
            .collapsePanel(reason: .keyboardShortcut)
        )
    }

    @MainActor
    func testControllerTracksKeyboardFocusFromForwardedInteractionActions() {
        let controller = MyVibeIslandAppKitOverlayController()

        XCTAssertFalse(controller.keyboardFocusRequested)

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.requestKeyboardFocus)
        ]))

        XCTAssertTrue(controller.keyboardFocusRequested)
        XCTAssertEqual(controller.lastForwardedInteractionAction, .requestKeyboardFocus)

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.releaseKeyboardFocus)
        ]))

        XCTAssertFalse(controller.keyboardFocusRequested)
        XCTAssertEqual(controller.lastForwardedInteractionAction, .releaseKeyboardFocus)
    }

    @MainActor
    func testControllerTracksTimerIntentsFromForwardedInteractionActions() {
        let controller = MyVibeIslandAppKitOverlayController()

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3)),
            .forwardInteractionAction(.scheduleAutoCollapse(delay: 4.0, generation: 5))
        ]))

        XCTAssertEqual(
            controller.pendingHoverReveal,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 0.2, generation: 3)
        )
        XCTAssertEqual(
            controller.pendingAutoCollapse,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 4.0, generation: 5)
        )

        controller.apply(.applyPanelPlan(actions: [
            .forwardInteractionAction(.cancelAutoCollapse)
        ]))

        XCTAssertEqual(
            controller.pendingHoverReveal,
            MyVibeIslandAppKitPanelInteractionTimerIntent(delay: 0.2, generation: 3)
        )
        XCTAssertNil(controller.pendingAutoCollapse)
        XCTAssertEqual(controller.lastForwardedInteractionAction, .cancelAutoCollapse)
    }

    @MainActor
    func testControllerHideClearsPendingInteractionIntentState() {
        let controller = MyVibeIslandAppKitOverlayController()

        controller.apply(.applyPanelPlan(actions: [
            .showPanel(displayState: .expanded),
            .forwardInteractionAction(.requestKeyboardFocus),
            .forwardInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 3)),
            .forwardInteractionAction(.scheduleAutoCollapse(delay: 4.0, generation: 5)),
            .forwardInteractionAction(.collapsePanel(reason: .keyboardShortcut)),
            .hidePanel(reason: .keyboardShortcut)
        ]))

        XCTAssertEqual(controller.currentPanelDisplayState, .closed)
        XCTAssertFalse(controller.keyboardFocusRequested)
        XCTAssertNil(controller.pendingHoverReveal)
        XCTAssertNil(controller.pendingAutoCollapse)
        XCTAssertNil(controller.lastForwardedInteractionAction)
    }

    @MainActor
    func testControllerPublishesIslandSurfaceDescriptorThroughInjectedClosure() {
        var descriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let controller = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { descriptor in
                descriptors.append(descriptor)
            }
        )
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill, .switcher],
            primarySessionIds: ["active"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 640, height: 420)
        )

        controller.renderIslandSurface(IslandSurfaceRenderList(sections: sections))

        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 640, height: 420),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .toggleExpandedPanel,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .switcher,
                    accessibilityLabel: "Session switcher",
                    detailLabel: "Focused session: active",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .switchFocusedSession,
                    isInteractive: true
                )
            ]
        )
        XCTAssertEqual(controller.lastIslandSurfaceDescriptor, descriptor)
        XCTAssertEqual(descriptors, [descriptor])
    }

    @MainActor
    func testControllerBuildsUnattachedIslandSurfaceViewThroughInjectedFactory() {
        var builtDescriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        var renderedViews: [NSView] = []
        let controller = MyVibeIslandAppKitOverlayController(
            buildIslandSurfaceView: { descriptor in
                builtDescriptors.append(descriptor)
                return NSView(frame: NSRect(
                    x: 0,
                    y: 0,
                    width: descriptor.contentSize.width,
                    height: descriptor.contentSize.height
                ))
            },
            renderIslandSurfaceView: { view in
                renderedViews.append(view)
            }
        )
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill],
            primarySessionIds: ["active"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 320, height: 120)
        )

        controller.renderIslandSurface(IslandSurfaceRenderList(sections: sections))

        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 120),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .toggleExpandedPanel,
                    isInteractive: true
                )
            ]
        )
        XCTAssertEqual(builtDescriptors, [descriptor])
        XCTAssertEqual(controller.lastIslandSurfaceView, renderedViews.first)
        XCTAssertEqual(renderedViews.count, 1)
        XCTAssertNil(renderedViews.first?.window)
    }

    @MainActor
    func testControllerAppliesRenderIslandSurfaceAction() {
        var renderedViews: [NSView] = []
        let controller = MyVibeIslandAppKitOverlayController(
            renderIslandSurfaceView: { view in
                renderedViews.append(view)
            }
        )
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill],
            primarySessionIds: ["active"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 320, height: 120)
        )

        controller.apply(.renderIslandSurface(IslandSurfaceRenderList(sections: sections)))

        XCTAssertEqual(controller.lastIslandSurfaceDescriptor?.items.map(\.section), [.compactPill])
        XCTAssertEqual(controller.lastIslandSurfaceView?.identifier?.rawValue, "my-vibe-island.surface")
        XCTAssertEqual(renderedViews.first?.identifier?.rawValue, "my-vibe-island.surface")
    }

    @MainActor
    func testControllerUsesOriginalCompactHostBeforeLegacyBuilderAndStillPublishesDescriptor() throws {
        var events: [String] = []
        var publishedDescriptors: [MyVibeIslandAppKitIslandSurfaceDescriptor] = []
        let renderer = makeUnifiedRenderer()
        let controller = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: {
                events.append("descriptor")
                publishedDescriptors.append($0)
            },
            buildOriginalIslandSurfaceView: { renderList in
                events.append("original")
                return renderer.render(renderList, screen: originalCompactScreen)
            },
            buildIslandSurfaceView: { _ in
                events.append("legacy")
                return NSView()
            },
            renderIslandSurfaceView: { _ in
                events.append("render")
            }
        )

        controller.renderIslandSurface(originalCompactRenderList())

        let host = try XCTUnwrap(originalCompactHost(in: controller.lastIslandSurfaceView))
        XCTAssertEqual(events, ["original", "descriptor", "render"])
        XCTAssertEqual(publishedDescriptors, [controller.lastIslandSurfaceDescriptor].compactMap { $0 })
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 239, height: 32))
    }

    @MainActor
    func testControllerRoutesNonNotchedClosedThroughOriginalTypedHostWithoutLegacyBuilder() throws {
        var events: [String] = []
        let renderer = makeUnifiedRenderer()
        let controller = MyVibeIslandAppKitOverlayController(
            renderIslandSurface: { _ in events.append("descriptor") },
            buildOriginalIslandSurfaceView: { renderList in
                events.append("original")
                return renderer.render(renderList, screen: originalCompactNonNotchedScreen)
            },
            buildIslandSurfaceView: { _ in
                events.append("legacy")
                return NSView()
            },
            renderIslandSurfaceView: { _ in events.append("render") }
        )

        controller.renderIslandSurface(originalCompactRenderList())

        let host = try XCTUnwrap(originalCompactHost(in: controller.lastIslandSurfaceView))
        XCTAssertEqual(events, ["original", "descriptor", "render"])
        XCTAssertEqual(host.rootView.displayClass, .nonNotched)
        XCTAssertEqual(host.rootView.surfaceSize, DisplaySize(width: 206, height: 30))
    }

    @MainActor
    func testControllerInvokesLegacyBuilderExactlyOnceForEachDeclinedOriginalRoute() {
        let cases: [(String, IslandSurfaceRenderList, OriginalNSScreenMetricsInput)] = [
            (
                "peek",
                originalCompactRenderList(displayStatus: .notificationPeek),
                originalCompactScreen
            ),
            (
                "expanded",
                originalCompactRenderList(displayStatus: .expanded),
                originalCompactScreen
            ),
        ]

        for (name, renderList, screen) in cases {
            var events: [String] = []
            let renderer = makeUnifiedRenderer()
            let controller = MyVibeIslandAppKitOverlayController(
                renderIslandSurface: { _ in
                    events.append("descriptor")
                },
                buildOriginalIslandSurfaceView: { renderList in
                    events.append("original")
                    return renderer.render(renderList, screen: screen)
                },
                buildIslandSurfaceView: { _ in
                    events.append("legacy")
                    return NSView()
                },
                renderIslandSurfaceView: { _ in
                    events.append("render")
                }
            )

            controller.renderIslandSurface(renderList)

            XCTAssertEqual(events, ["original", "descriptor", "legacy", "render"], name)
            XCTAssertNil(originalCompactHost(in: controller.lastIslandSurfaceView), name)
        }
    }

    @MainActor
    func testControllerDoesNotRenderLegacyFallbackForActionRequests() {
        var legacyBuildCount = 0
        var renderedViewCount = 0
        let controller = MyVibeIslandAppKitOverlayController(
            buildOriginalIslandSurfaceView: { _ in nil },
            buildIslandSurfaceView: { _ in
                legacyBuildCount += 1
                return NSView()
            },
            renderIslandSurfaceView: { _ in
                renderedViewCount += 1
            }
        )
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "request-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Bash"
        ))
        let sections = IslandSurfaceSections(
            visibleSections: [.actionRequests],
            primarySessionIds: ["session-1"],
            contentSize: DisplaySize(width: 320, height: 120),
            actionRequestPreviews: [request]
        )

        controller.renderIslandSurface(IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(legacyBuildCount, 0)
        XCTAssertEqual(renderedViewCount, 0)
    }
}

@MainActor
private func makeUnifiedRenderer() -> MyVibeIslandAppKitOriginalUnifiedHostingRenderer {
    MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
        onNavigateSwitcher: { _ in },
        onSubmitSwitcher: {},
        onCollapseSwitcher: {},
        onRequestFocus: {},
        onReleaseFocus: {}
    )
}

@MainActor
private func originalCompactHost(
    in container: NSView?
) -> NSHostingView<OriginalUnifiedIslandRootView>? {
    guard let container, container.subviews.count == 1 else { return nil }
    return container.subviews[0] as? NSHostingView<OriginalUnifiedIslandRootView>
}

private let originalCompactScreen = OriginalNSScreenMetricsInput(
    safeAreaTopInset: 32,
    frameWidth: 1512,
    auxiliaryTopLeftWidth: 663,
    auxiliaryTopRightWidth: 664
)

private let originalCompactNonNotchedScreen = OriginalNSScreenMetricsInput(
    safeAreaTopInset: 0,
    frameWidth: 1920,
    auxiliaryTopLeftWidth: 0,
    auxiliaryTopRightWidth: 0,
    screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1050)
)

private func originalCompactRenderList(
    sections: [IslandSurfaceSection] = [.compactPill],
    displayStatus: NotchDisplayStatus = .closed
) -> IslandSurfaceRenderList {
    IslandSurfaceRenderList(sections: IslandSurfaceSections(
        sessions: [
            AgentSession(
                id: "session-1",
                source: "codex",
                cwd: "/work/project",
                originalStatus: .processing,
                repoName: "project"
            ),
        ],
        visibleSections: sections,
        displayStatus: displayStatus,
        layoutMode: .compact,
        onboardingStep: nil,
        primarySessionIds: ["session-1"],
        contentSize: DisplaySize(width: 264, height: 36)
    ))
}

private struct OverlayControllerMatrixFixture: Codable, Equatable {
    let rows: [OverlayControllerMatrixRow]
}

private struct OverlayControllerMatrixRow: Codable, Equatable {
    let id: String
    let lastPresentationState: String?
    let lastSurfaceSections: [String]
    let lastSurfaceViewWidth: Double?
    let surfaceViewAttachedToWindow: Bool
    let lastDisplayReason: String?
    let routedOpenSettings: Bool
    let lastFrameWidth: Double?
    let lastShownState: String?
    let lastHiddenReason: String?
    let hasLastForwardedAction: Bool
    let currentPanelState: String
    let keyboardFocusRequested: Bool
    let pendingHoverReveal: Bool
    let pendingAutoCollapse: Bool
    let events: [String]

    @MainActor
    init(id: String, controller: MyVibeIslandAppKitOverlayController, events: [String]) {
        self.id = id
        self.lastPresentationState = controller.lastPresentation?.displayState.rawValue
        self.lastSurfaceSections = controller.lastIslandSurfaceDescriptor?.items.map { $0.section.rawValue } ?? []
        self.lastSurfaceViewWidth = controller.lastIslandSurfaceView.map { Double($0.frame.width) }
        self.surfaceViewAttachedToWindow = controller.lastIslandSurfaceView?.window != nil
        self.lastDisplayReason = controller.lastDisplayReason?.rawValue
        self.routedOpenSettings = controller.lastRoutedAction == .appCommand(.openSettings)
        self.lastFrameWidth = controller.lastAppliedFrame?.width
        self.lastShownState = controller.lastShownPanelState?.rawValue
        self.lastHiddenReason = controller.lastHiddenPanelReason?.rawValue
        self.hasLastForwardedAction = controller.lastForwardedInteractionAction != nil
        self.currentPanelState = controller.currentPanelDisplayState.rawValue
        self.keyboardFocusRequested = controller.keyboardFocusRequested
        self.pendingHoverReveal = controller.pendingHoverReveal != nil
        self.pendingAutoCollapse = controller.pendingAutoCollapse != nil
        self.events = events
    }
}
