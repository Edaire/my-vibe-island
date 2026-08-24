import AppKit
import Combine
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitOriginalUnifiedHostingRendererTests: XCTestCase {
    func testCompletionSiblingMeasurementIsIncludedInExpandedContentHeight() {
        XCTAssertEqual(
            OriginalExpandedContentHeight.resolve(
                baseListHeight: 96,
                completionSiblingHeight: 130
            ),
            226
        )
    }

    func testManualSessionExpansionHandlerReceivesTappedSessionID() {
        let renderer = makeRenderer()
        var receivedSessionID: String?
        renderer.setManualSessionExpansionHandler { receivedSessionID = $0 }

        renderer.toggleManualSessionExpansion("session-1")

        XCTAssertEqual(receivedSessionID, "session-1")
    }

    func testRetainedRendererDoesNotForceAppKitLayoutDuringPresentationReplacement() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("invalidateIntrinsicContentSize()"))
        XCTAssertFalse(source.contains("needsLayout = true"))
    }

    func testReplacingEqualActionRequestsDoesNotPublishAnotherModelChange() {
        let model = OriginalUnifiedIslandHostingModel(
            presentation: .compact(compactDescriptor()),
            actionRequests: []
        )
        var publicationCount = 0
        let observation = model.objectWillChange.sink {
            publicationCount += 1
        }

        model.replaceActionRequests([])

        XCTAssertEqual(publicationCount, 0)
        withExtendedLifetime(observation) {}
    }

    func testRendererRetainsContainerHostAndModelAcrossCompactExpandedCompact() throws {
        let renderer = makeRenderer()

        let compactContainer = try XCTUnwrap(renderer.render(
            compactRenderList(),
            screen: screen
        ))
        let compactHost = try XCTUnwrap(
            compactContainer.subviews.only as? NSHostingView<OriginalUnifiedIslandRootView>
        )
        let model = compactHost.rootView.model

        let expandedContainer = try XCTUnwrap(renderer.render(
            expandedRenderList(sessionCount: 3),
            screen: screen
        ))
        let expandedHost = try XCTUnwrap(
            expandedContainer.subviews.only as? NSHostingView<OriginalUnifiedIslandRootView>
        )
        let finalCompactContainer = try XCTUnwrap(renderer.render(
            compactRenderList(),
            screen: screen
        ))
        let finalCompactHost = try XCTUnwrap(
            finalCompactContainer.subviews.only as? NSHostingView<OriginalUnifiedIslandRootView>
        )

        XCTAssertTrue(compactContainer === expandedContainer)
        XCTAssertTrue(expandedContainer === finalCompactContainer)
        XCTAssertTrue(compactHost === expandedHost)
        XCTAssertTrue(expandedHost === finalCompactHost)
        XCTAssertTrue(model === expandedHost.rootView.model)
        XCTAssertTrue(model === finalCompactHost.rootView.model)
        XCTAssertEqual(model.presentation.displayState, .compact)
    }

    func testRendererPassesAuthoritativeExpandedAnimationInputsToTheRoot() throws {
        let session = AgentSession(
            id: "expanded-animation",
            source: "codex",
            cwd: "/work/expanded-animation",
            originalStatus: .processing
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            originalCompactRuntimeState: OriginalCompactRuntimeState(
                isMinimized: true,
                notchHeightOffset: 9
            ),
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            focusedSessionId: session.id
        ))
        let renderer = makeRenderer()

        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))

        XCTAssertEqual(renderer.model?.rootLayoutMode, .expanded)
        XCTAssertEqual(renderer.model?.rootIsMinimized, true)
        XCTAssertEqual(renderer.model?.rootNotchHeightOffset, 9)
    }

    func testMeasuredExpandedHeightDoesNotResetIndependentRootAnimationInputs() throws {
        let session = AgentSession(
            id: "expanded-measurement-inputs",
            source: "codex",
            cwd: "/work/expanded-measurement-inputs",
            originalStatus: .processing
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            originalCompactRuntimeState: OriginalCompactRuntimeState(
                isMinimized: true,
                notchHeightOffset: 9
            ),
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            focusedSessionId: session.id
        ))
        let renderer = makeRenderer()

        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))
        renderer.replaceMeasuredExpandedContentHeight(180, sessionIDs: [session.id])

        XCTAssertEqual(renderer.model?.rootIsMinimized, true)
        XCTAssertEqual(renderer.model?.rootLayoutMode, .expanded)
        XCTAssertEqual(renderer.model?.rootNotchHeightOffset, 9)
    }

    func testRendererKeepsOriginalCompactSurfaceWhenUsageSectionIsPresent() throws {
        let session = AgentSession(
            id: "compact-session",
            source: "codex",
            cwd: "/work/compact",
            originalStatus: .processing,
            repoName: "compact"
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .usageInfo],
            displayStatus: .closed,
            layoutMode: .compact,
            onboardingStep: nil,
            primarySessionIds: [session.id]
        ))
        let renderer = makeRenderer()

        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))

        XCTAssertEqual(renderer.model?.presentation.displayState, .compact)
    }

    func testRendererRefreshesInteractionGeometryAfterScreenSizeChanges() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))
        let resizedScreen = OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1728,
            auxiliaryTopLeftWidth: 771,
            auxiliaryTopRightWidth: 772,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1728, height: 1117),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1728, height: 1084)
        )

        _ = try XCTUnwrap(renderer.refreshScreen(resizedScreen))

        XCTAssertEqual(renderer.interactionGeometry?.compactFrame.x, 734.5)
        XCTAssertEqual(renderer.interactionGeometry?.compactFrame.y, 1084)
    }

    func testRendererPresentsExplicitPeekOnRetainedUnifiedSurface() throws {
        let renderer = makeRenderer()
        let compactContainer = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))
        let notification = OriginalPeekNotification(
            id: "peek-1",
            title: "Done",
            detail: "Task completed",
            provider: .openai,
            level: .info
        )

        let peekContainer = try XCTUnwrap(renderer.renderPeek(
            .peek(notification, kind: .taskComplete),
            compactRenderList: compactRenderList(),
            screen: screen
        ))

        XCTAssertTrue(compactContainer === peekContainer)
        guard case let .peek(compact, descriptor, state) = renderer.model?.presentation else {
            return XCTFail("Expected peek presentation")
        }
        XCTAssertEqual(compact.surfaceSize, DisplaySize(width: 239, height: 33))
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 327, height: 71))
        XCTAssertEqual(state, .peek(notification, kind: .taskComplete))
        XCTAssertEqual(renderer.interactionGeometry?.expandedFrame, DisplayFrame(
            x: 592.5,
            y: 911,
            width: 327,
            height: 71
        ))
    }

    func testCompletionRenderUsesTheCompleteOrdinarySessionList() throws {
        let renderer = makeRenderer()

        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 2), screen: screen))

        guard case let .expanded(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected expanded completion notification")
        }
        XCTAssertEqual(descriptor.contentPlan.sessionRows.map(\.id), ["expanded-0", "expanded-1"])
        XCTAssertNil(descriptor.contentPlan.highlightedID)
        XCTAssertEqual(descriptor.contentPlan.completionBodyRowID, "expanded-0")
        XCTAssertNil(
            Mirror(reflecting: descriptor.contentPlan).children.first { $0.label == "presentationMode" }
        )
    }

    func testRendererRoutesSwitcherToRetainedSwiftUISurfaceWithExactIDs() throws {
        let renderer = makeRenderer()

        let container = try XCTUnwrap(renderer.render(
            switcherRenderList(),
            screen: screen
        ))
        let host = try XCTUnwrap(
            container.subviews.only as? NSHostingView<OriginalUnifiedIslandRootView>
        )

        guard case let .switcher(descriptor) = host.rootView.model.presentation else {
            return XCTFail("Expected switcher presentation")
        }

        XCTAssertEqual(
            descriptor.contentPlan.sessionRows.map(\.id),
            ["switcher-1", "switcher-2", "switcher-3"]
        )
        XCTAssertEqual(Set(descriptor.contentPlan.sessionRows.map(\.id)).count, 3)
        XCTAssertEqual(descriptor.highlightedID, "switcher-2")
        XCTAssertEqual(
            host.rootView.model.presentation.displayState,
            .expanded
        )
        XCTAssertEqual(host.rootView.surfaceSize.width, 640)
        XCTAssertEqual(
            renderer.interactionGeometry?.expandedFrame.width,
            640
        )
    }

    func testRendererCarriesSwitcherHighlightIntoTheOrdinarySessionCardPlan() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(switcherRenderList(), screen: screen))

        var state = SwitcherRuntimeState()
        state.open(
            sessionIDs: ["switcher-1", "switcher-2", "switcher-3"],
            highlightedID: "switcher-3"
        )
        renderer.replaceSwitcherState(state)

        guard case let .switcher(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected switcher presentation")
        }
        XCTAssertEqual(descriptor.highlightedID, "switcher-3")
        XCTAssertEqual(descriptor.contentPlan.highlightedID, "switcher-3")
        XCTAssertEqual(descriptor.contentPlan.displayRows.first?.id, "switcher-3")
    }

    func testSwitcherHighlightSurvivesAnUnrelatedRenderListRefresh() throws {
        let renderer = makeRenderer()
        let renderList = switcherRenderList()
        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))

        var state = SwitcherRuntimeState()
        state.open(
            sessionIDs: ["switcher-1", "switcher-2", "switcher-3"],
            highlightedID: "switcher-3"
        )
        renderer.replaceSwitcherState(state)

        // V3 keeps `_switcherHighlightedId` separate from ordinary focused
        // session state. A session publication therefore must not reset the
        // active switcher row to `focusedSessionId`.
        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))

        guard case let .switcher(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected switcher presentation")
        }
        XCTAssertEqual(descriptor.highlightedID, "switcher-3")
        XCTAssertEqual(descriptor.contentPlan.highlightedID, "switcher-3")
    }

    func testSwitcherHighlightFallsBackWhenTheHighlightedSessionDisappears() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(switcherRenderList(), screen: screen))

        var state = SwitcherRuntimeState()
        state.open(
            sessionIDs: ["switcher-1", "switcher-2", "switcher-3"],
            highlightedID: "switcher-3"
        )
        renderer.replaceSwitcherState(state)

        let refreshedList = switcherRenderList(sessionIDs: ["switcher-1", "switcher-2"])
        _ = try XCTUnwrap(renderer.render(refreshedList, screen: screen))

        guard case let .switcher(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected switcher presentation")
        }
        XCTAssertEqual(descriptor.highlightedID, "switcher-2")
        XCTAssertEqual(descriptor.contentPlan.highlightedID, "switcher-2")
    }

    func testRendererSwitcherDescriptorPreservesDuplicateSessionOccurrences() throws {
        let duplicate = AgentSession(
            id: "same",
            source: "codex",
            cwd: "/work/same",
            originalStatus: .processing,
            repoName: "same"
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [duplicate, duplicate],
            visibleSections: [.expandedPanel, .sessionCards, .switcher],
            displayStatus: .switcher,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: ["same", "same"],
            focusedSessionId: "same"
        ))
        let renderer = makeRenderer()

        _ = try XCTUnwrap(renderer.render(renderList, screen: screen))
        guard case let .switcher(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected switcher presentation")
        }

        XCTAssertEqual(descriptor.contentPlan.sessionRows.map(\.id), ["same"])
        XCTAssertEqual(Set(descriptor.contentPlan.sessionRows.map(\.id)).count, 1)
    }

    func testRendererUsesFixedTransparentHostButPublishesVisibleExpandedInteractionFrame() async throws {
        let renderer = makeRenderer()
        let container = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))
        let host = try XCTUnwrap(
            container.subviews.only as? NSHostingView<OriginalUnifiedIslandRootView>
        )

        XCTAssertEqual(container.frame.size, NSSize(width: 680, height: 580))
        XCTAssertEqual(host.frame, container.bounds)
        XCTAssertTrue(host.wantsLayer)
        XCTAssertEqual(host.layer?.backgroundColor, NSColor.clear.cgColor)
        try await waitForFittingSize(NSSize(width: 239, height: 33), host: host)
        XCTAssertEqual(renderer.interactionGeometry?.compactFrame, DisplayFrame(
            x: 626.5,
            y: 949,
            width: 259,
            height: 33
        ))
        XCTAssertEqual(renderer.interactionGeometry?.menuBarFrame, DisplayFrame(
            x: 566.5,
            y: 949,
            width: 379,
            height: 33
        ))

        _ = renderer.render(expandedRenderList(sessionCount: 3), screen: screen)

        let expectedVisibleSurface = try XCTUnwrap(renderer.hostingView?.rootView.surfaceSize)
        XCTAssertEqual(expectedVisibleSurface.width, 640)
        try await waitForFittingWidth(expectedVisibleSurface.width, host: host)
        guard case let .expanded(descriptor) = renderer.model?.presentation else {
            return XCTFail("Expected expanded presentation")
        }
        XCTAssertEqual(renderer.interactionGeometry?.expandedFrame, DisplayFrame(
            x: descriptor.geometry.panelFrame.x + descriptor.geometry.surfaceFrame.x,
            y: descriptor.geometry.panelFrame.y + descriptor.geometry.surfaceFrame.y,
            width: descriptor.geometry.surfaceFrame.width,
            height: descriptor.geometry.surfaceFrame.height
        ))
    }

    func testUnsupportedStateFallsBackWithoutDiscardingRetainedHost() throws {
        let renderer = makeRenderer()
        let compactContainer = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))

        XCTAssertNil(renderer.render(unsupportedRenderList(), screen: screen))
        XCTAssertNil(renderer.interactionGeometry)

        let restored = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))
        XCTAssertTrue(compactContainer === restored)
    }

    func testMeasuredExpandedContentHeightUpdatesRetainedPresentationThroughThresholdGate() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 3), screen: screen))

        renderer.replaceMeasuredExpandedContentHeight(123)
        XCTAssertEqual(renderer.hostingView?.rootView.surfaceSize, DisplaySize(width: 640, height: 163))

        renderer.replaceMeasuredExpandedContentHeight(123.5)
        XCTAssertEqual(renderer.hostingView?.rootView.surfaceSize, DisplaySize(width: 640, height: 163))

        renderer.replaceMeasuredExpandedContentHeight(123.500_001)
        XCTAssertEqual(
            renderer.hostingView?.rootView.surfaceSize,
            DisplaySize(width: 640, height: 163.500_001)
        )
    }

    func testMeasuredExpandedHeightRepublishesInteractionGeometry() throws {
        var expandedFrames: [DisplayFrame] = []
        let renderer = MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
            onNavigateSwitcher: { _ in },
            onSubmitSwitcher: {},
            onCollapseSwitcher: {},
            onRequestFocus: {},
            onReleaseFocus: {},
            onInteractionGeometryChange: { expandedFrames.append($0.expandedFrame) }
        )
        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 1), screen: screen))
        let initialFrame = try XCTUnwrap(expandedFrames.last)

        renderer.replaceMeasuredExpandedContentHeight(260, sessionIDs: ["expanded-0"])

        let measuredFrame = try XCTUnwrap(expandedFrames.last)
        XCTAssertGreaterThan(expandedFrames.count, 1)
        XCTAssertEqual(initialFrame, DisplayFrame(x: 436, y: 856, width: 640, height: 126))
        XCTAssertEqual(measuredFrame, DisplayFrame(x: 436, y: 682, width: 640, height: 300))
    }

    func testMeasuredHeightIsInvalidatedWhenTheFocusedVisibleRowChanges() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(
            expandedRenderList(sessionCount: 5, focusedIndex: 0),
            screen: screen
        ))
        renderer.replaceMeasuredExpandedContentHeight(374)

        _ = try XCTUnwrap(renderer.render(
            expandedRenderList(sessionCount: 5, focusedIndex: 1),
            screen: screen
        ))

        // Clearing the stale measurement exposes the new natural five-row
        // measurement (374pt), which the IDA resolver expands by 40pt.
        XCTAssertEqual(renderer.hostingView?.rootView.surfaceSize, DisplaySize(width: 640, height: 414))
    }

    func testLateExpandedMeasurementCannotRestoreGeometryAfterUnsupportedState() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 3), screen: screen))

        XCTAssertNil(renderer.render(unsupportedRenderList(), screen: screen))
        renderer.replaceMeasuredExpandedContentHeight(200)

        XCTAssertNil(renderer.interactionGeometry)
        XCTAssertEqual(renderer.hostingView?.rootView.surfaceSize, DisplaySize(width: 640, height: 270))
    }

    func testLateMeasurementFromPreviousSessionIDsCannotResizeNewExpandedRows() throws {
        let renderer = makeRenderer()
        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 3), screen: screen))
        let previousIDs = ["expanded-0", "expanded-1", "expanded-2"]

        _ = try XCTUnwrap(renderer.render(expandedRenderList(sessionCount: 2), screen: screen))
        renderer.replaceMeasuredExpandedContentHeight(300, sessionIDs: previousIDs)

        XCTAssertEqual(renderer.hostingView?.rootView.surfaceSize, DisplaySize(width: 640, height: 198))
    }

    private func waitForFittingSize(
        _ expected: NSSize,
        host: NSHostingView<OriginalUnifiedIslandRootView>
    ) async throws {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            host.layoutSubtreeIfNeeded()
            if host.fittingSize == expected, host.intrinsicContentSize == expected {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        } while Date() < deadline
        XCTAssertEqual(host.fittingSize, expected)
        XCTAssertEqual(host.intrinsicContentSize, expected)
    }

    private func waitForFittingWidth(
        _ expected: Double,
        host: NSHostingView<OriginalUnifiedIslandRootView>
    ) async throws {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            host.layoutSubtreeIfNeeded()
            if host.fittingSize.width == expected, host.intrinsicContentSize.width == expected {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        } while Date() < deadline
        XCTAssertEqual(host.fittingSize.width, expected)
        XCTAssertEqual(host.intrinsicContentSize.width, expected)
    }

    private func makeRenderer() -> MyVibeIslandAppKitOriginalUnifiedHostingRenderer {
        MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
            onNavigateSwitcher: { _ in },
            onSubmitSwitcher: {},
            onCollapseSwitcher: {},
            onRequestFocus: {},
            onReleaseFocus: {}
        )
    }

    private func compactRenderList() -> IslandSurfaceRenderList {
        let session = AgentSession(
            id: "compact-session",
            source: "codex",
            cwd: "/work/compact",
            originalStatus: .processing,
            repoName: "compact"
        )
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill],
            displayStatus: .closed,
            layoutMode: .compact,
            onboardingStep: nil,
            primarySessionIds: [session.id]
        ))
    }

    private func notificationRenderList() -> IslandSurfaceRenderList {
        let session = AgentSession(
            id: "notification-session",
            source: "codex",
            cwd: "/work/notification",
            originalStatus: .ended,
            lastAssistantMessage: "Completed output",
            firstUserMessage: "Run the task",
            lastUserMessage: "Run the task",
            hasUnreadCompletion: true
        )
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .notificationPeek],
            displayStatus: .notificationPeek,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            notificationSessionIds: [session.id],
            focusedSessionId: session.id
        ))
    }

    private func compactDescriptor() -> OriginalCompactHostingDescriptor {
        OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: compactRenderList(),
            screen: screen
        )!
    }

    private func expandedRenderList(
        sessionCount: Int,
        focusedIndex: Int = 0
    ) -> IslandSurfaceRenderList {
        let sessions = (0..<sessionCount).map { index in
            AgentSession(
                id: "expanded-\(index)",
                source: "codex",
                cwd: "/work/expanded-\(index)",
                originalStatus: .processing,
                repoName: "expanded-\(index)"
            )
        }
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions.indices.contains(focusedIndex) ? sessions[focusedIndex].id : nil
        ))
    }

    private func switcherRenderList(
        sessionIDs: [String] = ["switcher-1", "switcher-2", "switcher-3"]
    ) -> IslandSurfaceRenderList {
        let sessions = sessionIDs.map { id in
            AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: .processing,
                repoName: id
            )
        }
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.expandedPanel, .sessionCards, .switcher],
            displayStatus: .switcher,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: "switcher-2"
        ))
    }

    private func unsupportedRenderList() -> IslandSurfaceRenderList {
        IslandSurfaceRenderList(sections: IslandSurfaceSections(
            visibleSections: [.compactPill, .notificationPeek],
            displayStatus: .notificationPeek
        ))
    }

    private var screen: OriginalNSScreenMetricsInput {
        OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
        )
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyVibeIslandApp")
            .appendingPathComponent("MyVibeIslandAppKitOriginalUnifiedHostingRenderer.swift")
    }
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
