import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalUnifiedIslandRootViewTests: XCTestCase {
    func testExpandedUsageHeaderMatchesTheCapturedCodexWaitingStateOnly() {
        let codex = OriginalExpandedSessionRow(session: AgentSession(
            id: "codex-waiting",
            source: "codex",
            cwd: "/private/tmp"
        ))
        let nonCodex = OriginalExpandedSessionRow(session: AgentSession(
            id: "claude-waiting",
            source: "claude",
            cwd: "/private/tmp"
        ))
        let unavailable = UsageInfoBar(
            status: .unavailable,
            title: "Codex",
            primaryText: "Usage unavailable",
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(
            OriginalExpandedUsageWaitingHeaderPlan.resolve(
                usageInfoBar: unavailable,
                rows: [codex]
            ),
            .waitingForCodexActivity
        )
        XCTAssertNil(OriginalExpandedUsageWaitingHeaderPlan.resolve(
            usageInfoBar: unavailable,
            rows: [nonCodex]
        ))
        XCTAssertNil(OriginalExpandedUsageWaitingHeaderPlan.resolve(
            usageInfoBar: UsageInfoBar(
                status: .available,
                title: "Codex",
                providerDisplayName: "Codex"
            ),
            rows: [codex]
        ))
    }

    func testCompactBodyUsesSharedRootAndAcceptedRowWithoutLegacyLifecycleRoot() throws {
        let model = OriginalUnifiedIslandHostingModel(presentation: .compact(compactDescriptor()))
        let descendants = mirroredDescendants(of: OriginalUnifiedIslandRootView(model: model).body)

        XCTAssertEqual(descendants.compactMap { $0 as? OriginalCompactRowView }.count, 1)
    }

    func testCompactContentUsesTheDescriptorPrimarySessionWithoutLocalRotation() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        // IDA: both compact renderers read only the first already-sorted display
        // session. A root-local timer is not part of the original view family.
        XCTAssertFalse(source.contains("Timer.publish("))
        XCTAssertFalse(source.contains("compactSessionIndex"))
        XCTAssertFalse(source.contains("contentPlan(for:"))
        XCTAssertFalse(source.contains("advanceCompactSession"))
    }

    func testPeekBodyRetainsCompactRowAndAppendsFrozenSupplementalRow() {
        let notification = OriginalPeekNotification(
            id: "peek-1",
            title: "Done",
            detail: "Task completed",
            provider: .openai,
            level: .info
        )
        let compact = compactDescriptor()
        let peek = OriginalPeekHostingDescriptor(
            compactSurfaceSize: compact.surfaceSize,
            screenWidth: 1512
        )
        let model = OriginalUnifiedIslandHostingModel(presentation: .peek(
            compact: compact,
            descriptor: peek,
            state: .peek(notification, kind: .taskComplete)
        ))
        let root = OriginalUnifiedIslandRootView(model: model)
        let descendants = mirroredDescendants(of: root.body)

        XCTAssertEqual(root.surfaceSize, DisplaySize(width: 327, height: 71))
        XCTAssertEqual(root.visibleSurfaceSize, DisplaySize(width: 327, height: 71))
        XCTAssertEqual(model.presentation.displayState, .peek)
        XCTAssertEqual(descendants.compactMap { $0 as? OriginalCompactRowView }.count, 1)
        XCTAssertEqual(descendants.compactMap { $0 as? OriginalPeekSupplementalView }.count, 1)
    }

    func testCompletionFlashIsDrivenByCompactDescriptorTickAndPassedToRow() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "@State private var completionFlashProgress = 0.0",
            ".onChange(of: model.completionFlashTick, initial: false)",
            "completionFlashProgress = 0.9",
            ".easeOut(duration: 1.1)",
            "completionFlashProgress: completionFlashProgress",
        ] {
            XCTAssertTrue(source.contains(required), "Missing completion flash wiring: \(required)")
        }
    }

    func testCompletionFlashUsesTheOriginalDirectStateWriteTransaction() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let onChangeRange = try XCTUnwrap(source.range(
            of: ".onChange(of: model.completionFlashTick, initial: false)"
        ))
        let completionHandler = String(source[onChangeRange.lowerBound...])

        XCTAssertTrue(completionHandler.contains("completionFlashProgress = 0.9"))
        XCTAssertTrue(completionHandler.contains("withAnimation(.easeOut(duration: 1.1))"))
        XCTAssertFalse(completionHandler.contains("DispatchQueue.main.async"))
    }

    func testCompletionFlashIgnoresTicksWhileTheOriginalRootIsExpanded() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let onChangeRange = try XCTUnwrap(source.range(
            of: ".onChange(of: model.completionFlashTick, initial: false)"
        ))
        let completionHandler = String(source[onChangeRange.lowerBound...])

        // V3 sub_1006CA1B4 reads the root status byte and returns when it is
        // `expanded` (raw value 2), before assigning the compact flash state.
        XCTAssertTrue(completionHandler.contains(
            "guard model.presentation.displayState != .expanded else { return }"
        ))
    }

    func testCompletionFlashTickIsRootStateIndependentOfExpandedPresentation() {
        let inputs = OriginalUnifiedIslandRootAnimationInputs(
            isMinimized: false,
            isHovering: false,
            layoutMode: .compact,
            notchHeightOffset: 0,
            completionFlashTick: 7
        )
        let model = OriginalUnifiedIslandHostingModel(
            presentation: .compact(compactDescriptor(completionFlashTick: 7)),
            rootAnimationInputs: inputs
        )

        model.replace(
            .expanded(expandedDescriptor()),
            rootAnimationInputs: OriginalUnifiedIslandRootAnimationInputs(
                isMinimized: false,
                isHovering: false,
                layoutMode: .expanded,
                notchHeightOffset: 0,
                completionFlashTick: 8
            )
        )

        XCTAssertEqual(model.presentation.displayState, .expanded)
        XCTAssertEqual(model.completionFlashTick, 8)
    }

    func testCompletionFlashTickDefaultsFromCompactPresentation() {
        let model = OriginalUnifiedIslandHostingModel(
            presentation: .compact(compactDescriptor(completionFlashTick: 7))
        )

        XCTAssertEqual(model.completionFlashTick, 7)
    }

    func testExpandedRootUsesTheVisibleSurfaceWidthWithTheMeasuredContentHeight() throws {
        let descriptor = expandedDescriptor()
        let model = OriginalUnifiedIslandHostingModel(presentation: .expanded(descriptor))
        let root = OriginalUnifiedIslandRootView(model: model)
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        let expectedSurface = descriptor.surfaceSize
        XCTAssertEqual(root.surfaceSize, expectedSurface)
        XCTAssertEqual(root.visibleSurfaceSize, expectedSurface)
        XCTAssertTrue(source.contains(
            ".padding(.bottom, CGFloat(descriptor.rootLayoutPlan.innerHorizontalBottomPadding))"
        ))
        XCTAssertTrue(source.contains(
            ".padding(.horizontal, CGFloat(descriptor.rootLayoutPlan.outerHorizontalInset))"
        ))
    }

    func testExpandedInteractionFrameUsesTheVisibleSurfaceForInputRouting() throws {
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)
        let expandedCase = try XCTUnwrap(source.range(of: "case let .expanded(descriptor):"))
        let switcherCase = try XCTUnwrap(source.range(
            of: "case let .switcher(descriptor):",
            range: expandedCase.upperBound..<source.endIndex
        ))
        let expandedBranch = String(source[expandedCase.lowerBound..<switcherCase.lowerBound])

        XCTAssertTrue(expandedBranch.contains("let surfaceFrame = descriptor.geometry.surfaceFrame"))
        XCTAssertTrue(expandedBranch.contains("y: descriptor.geometry.panelFrame.y + surfaceFrame.y"))
        XCTAssertTrue(expandedBranch.contains("height: surfaceFrame.height"))
    }

    func testExpandedBodyUsesSharedRootWithExpandedSessionsList() throws {
        let model = OriginalUnifiedIslandHostingModel(presentation: .expanded(expandedDescriptor()))
        let descendants = mirroredDescendants(of: OriginalUnifiedIslandRootView(model: model).body)

        XCTAssertEqual(descendants.compactMap { $0 as? OriginalExpandedSessionsListView }.count, 1)
        XCTAssertEqual(descendants.compactMap { $0 as? OriginalExpandedHeaderControlsView }.count, 1)
    }

    func testDisplayStateContentDoesNotAddAnIndependentTransitionToTheRootGeometry() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(".id(presentation.displayState)"))
        // IDA sub_1004F2800 builds the root ZStack and attaches state-keyed
        // animations, but has no View.transition / AnyTransition constructor.
        XCTAssertFalse(source.contains(".transition(originalDisplayStatusTransition)"))
        XCTAssertFalse(source.contains("private var originalDisplayStatusTransition"))
    }

    func testRootDoesNotAttachAnUnsupportedStatusContentTransition() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        // Matching V3 `NotchContentView.body` (`sub_1006C5718` and its root
        // layout consumer `sub_1006C638C`) contains no transition constructor.
        // Geometry changes are driven by the recovered keyed animation chain.
        XCTAssertFalse(source.contains(".transition(originalStatusContentTransition)"))
        XCTAssertFalse(source.contains("private var originalStatusContentTransition"))
    }

    func testStateContentIsClippedToTheAnimatingNotchSurface() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let stateContentRange = try XCTUnwrap(source.range(of: "stateContent(presentation)"))
        let rootFrameRange = try XCTUnwrap(source.range(
            of: "\n        .frame(\n            width: CGFloat(fittingSize.width)",
            range: stateContentRange.lowerBound..<source.endIndex
        ))
        let stateContent = String(source[stateContentRange.lowerBound..<rootFrameRange.lowerBound])

        XCTAssertTrue(stateContent.contains("width: CGFloat(visibleSize.width)"))
        XCTAssertTrue(stateContent.contains("height: CGFloat(visibleSize.height)"))
        XCTAssertTrue(stateContent.contains(".clipShape(OriginalNotchShape("))
    }

    func testExpandedStateContentMeasuresItsNaturalHeightBeforeTheNotchSurfaceClipsIt() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        // The expanded list owns a bounded ScrollView.  Forcing the entire
        // root content to its intrinsic vertical height makes every card lay
        // out before the 342pt viewport can be drawn, which delays hover
        // expansion and defeats scrolling.
        XCTAssertFalse(source.contains(".fixedSize(horizontal: false, vertical: presentationIsExpanded)"))
    }

    func testRootHoverUsesTheVisibleNotchSurfaceInsteadOfTheTransparentHost() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let stateContentRange = try XCTUnwrap(source.range(of: "stateContent(presentation)"))
        let backgroundRange = try XCTUnwrap(source.range(of: "Color.black"))
        let backgroundSurface = String(source[backgroundRange.lowerBound..<stateContentRange.lowerBound])
        let contentSurfaceEnd = try XCTUnwrap(source.range(
            of: "\n        }\n        .animation(",
            range: stateContentRange.lowerBound..<source.endIndex
        ))
        let contentSurface = String(source[stateContentRange.lowerBound..<contentSurfaceEnd.lowerBound])

        XCTAssertFalse(source.contains(".contentShape(Rectangle())"))
        XCTAssertFalse(backgroundSurface.contains(".onHover(perform: onExpandedContentHoverChange)"))
        XCTAssertTrue(contentSurface.contains(".onHover(perform: onExpandedContentHoverChange)"))
    }

    func testRootHoverDoesNotDriveTheAppKitExpandedLeaveLifecycle() throws {
        let source = try String(contentsOf: platformCompositionSourceURL, encoding: .utf8)

        // V3 NotchWindowController owns expanded-pointer state through its
        // explicit AppKit hit rectangle. A SwiftUI root hover transition is
        // not allowed to race that state machine while its geometry animates.
        XCTAssertFalse(source.contains(
            "notchPanelController.processExpandedContentHover(isInside)"
        ))
    }

    func testExpandedSessionsListKeepsAcceptedOuterStructureWithoutCardTranslation() throws {
        let source = try String(contentsOf: expandedSessionsListSourceURL, encoding: .utf8)

        for required in [
            "ScrollViewReader { proxy in",
            "ScrollView(.vertical, showsIndicators: false)",
            "VStack(alignment: .center, spacing: 4)",
            ".padding(.bottom, 6)",
            "mountsCompletionBody: mountsCompletionBodies && contentPlan.completionBodyRowID == row.id",
            "reservesHeaderControls: row.id == visibility.visibleRows.first?.id",
        ] {
            XCTAssertTrue(source.contains(required), "Missing expanded list structure: \(required)")
        }

        XCTAssertFalse(source.contains("LazyVStack"))
        XCTAssertFalse(source.contains(".transformEffect("))

        let standard = OriginalExpandedSessionsListLayoutPlan.original
        XCTAssertEqual(standard.innerHorizontalPadding, 8)
        XCTAssertEqual(standard.outerHorizontalPadding, 0)
        XCTAssertEqual(
            Mirror(reflecting: standard).children.first { $0.label == "usesOuterScrollView" }?.value as? Bool,
            true
        )
    }

    func testCompletionPreviewReusesTheExpandedSessionCardWithoutTheListWrapper() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if let completionPreviewRow = descriptor.completionPreviewRow"))
        XCTAssertTrue(source.contains("OriginalExpandedSessionCardView("))
        XCTAssertTrue(source.contains("mountsCompletionBody: true"))
        XCTAssertTrue(source.contains("OriginalExpandedStatusTwoLayoutPlan.completionHorizontalInset"))
        XCTAssertTrue(source.contains("OriginalExpandedStatusTwoLayoutPlan.completionTopInset"))
    }

    func testCompletionPreviewUsesTheRecoveredStatusTwoBaseInsets() {
        XCTAssertEqual(OriginalExpandedStatusTwoLayoutPlan.baseHorizontalInset, 13)
        XCTAssertEqual(OriginalExpandedStatusTwoLayoutPlan.baseVerticalInset, 4)
        XCTAssertEqual(OriginalExpandedStatusTwoLayoutPlan.completionHorizontalInset, 8)
        XCTAssertEqual(OriginalExpandedStatusTwoLayoutPlan.completionTopInset, 4)
    }

    func testOrdinaryExpandedRootLeavesHorizontalInsetToSessionsList() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(
            ".padding(.bottom, CGFloat(descriptor.rootLayoutPlan.innerHorizontalBottomPadding))"
        ))
        XCTAssertFalse(source.contains(
            ".padding([.horizontal, .bottom], CGFloat(descriptor.rootLayoutPlan.innerHorizontalBottomPadding))"
        ))
        XCTAssertFalse(source.contains("appliesSharedHorizontalInsets"))
    }

    func testHighlightedReorderingReservesHeaderControlsOnlyForFirstDisplayedRow() {
        let rows = ["session-0", "session-1", "session-2"].map { id in
            OriginalExpandedSessionRow(session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: .processing
            ))
        }
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: rows,
            highlightedID: "session-1"
        )
        let reservations = contentPlan.displayRows.map { row in
            (row.id, row.id == contentPlan.displayRows.first?.id)
        }

        XCTAssertEqual(reservations.map(\.0), ["session-1", "session-0", "session-2"])
        XCTAssertEqual(reservations.map(\.1), [true, false, false])
    }

    func testExpandedRootStoresSoundPreferenceAndRoutesSettingsControl() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("@AppStorage(SoundPreferencesStore.Key.isEnabled)"))
        XCTAssertTrue(source.contains("soundEnabled.toggle()"))
        XCTAssertTrue(source.contains("onOpenSettings: onOpenSettings"))
    }

    func testProductionSourceRetainsRecoveredRootSpringsWithoutUnsupportedContentTransition() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            ".spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)",
            "OriginalRootAnimationContract.rootHoverSpring",
            ".spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)",
            ".spring(response: 0.45, dampingFraction: 1, blendDuration: 0)",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }

        for forbidden in [
            ".transition(originalDisplayStatusTransition)",
            "private var originalDisplayStatusTransition",
            ".animation(\n            .spring(response: 0.42",
            ".transition(.opacity)",
            ".id(presentation.displayState)",
            "OriginalNotchContentView(",
            "OriginalExpandedRootSurfaceView(",
            "NSHostingView",
            "NSPanel",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
    }

    func testProductionSourceAppliesRecoveredRootSpringsToOriginalStateInputs() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)"))
        XCTAssertTrue(source.contains("value: model.rootIsMinimized"))
        XCTAssertTrue(source.contains("value: model.rootLayoutMode"))
    }

    func testProductionSourceAnimatesHoverScaleWithRecoveredHoverSpring() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("OriginalRootAnimationContract.rootHoverSpring"))
        XCTAssertTrue(source.contains("value: model.rootIsHovering"))
    }

    func testRootLayoutAnimationValueChangesWhenPresentationExpands() {
        let model = OriginalUnifiedIslandHostingModel(presentation: .compact(compactDescriptor()))

        model.replace(.expanded(expandedDescriptor()))

        XCTAssertEqual(String(describing: model.rootLayoutMode), "expanded")
    }

    func testProductionSourceAnimatesRootGeometryWithRecoveredV3StateKeys() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)"))
        XCTAssertTrue(source.contains(".spring(response: 0.45, dampingFraction: 1, blendDuration: 0)"))
        XCTAssertTrue(source.contains("value: animationContract.displayStatusTarget"))
        XCTAssertTrue(source.contains("value: animationContract.expandedWidthTarget"))
        XCTAssertTrue(source.contains("value: animationContract.expandedHeightTarget"))
        XCTAssertTrue(source.contains("value: animationContract.visibleSurfaceHeightTarget"))
        XCTAssertFalse(source.contains("compactHeightTarget(for:"))
        XCTAssertTrue(source.contains("value: model.rootLayoutMode"))
    }

    func testGeometryAnimationsAreAttachedToTheWholeRootSurface() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let rootSurfaceEnd = try XCTUnwrap(source.range(
            of: "\n        }\n        .animation(",
            range: source.range(of: "return ZStack(alignment: .top)")!.lowerBound..<source.endIndex
        ))
        let geometryAnimation = try XCTUnwrap(source.range(
            of: "value: animationContract.visibleSurfaceHeightTarget"
        ))

        // V3 sub_1006C638C applies the width, measured-height, and visible
        // height animation chain after it has built the root surface. The
        // black notch background must be inside that chain with the content.
        XCTAssertGreaterThan(geometryAnimation.lowerBound, rootSurfaceEnd.lowerBound)
    }

    private func compactDescriptor(completionFlashTick: Int = 0) -> OriginalCompactHostingDescriptor {
        OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: compactRenderList,
            screen: OriginalNSScreenMetricsInput(
                safeAreaTopInset: 32,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: 663,
                auxiliaryTopRightWidth: 664,
                screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
            )
        )!.replacingCompletionFlashTick(completionFlashTick)
    }

    private func expandedDescriptor() -> OriginalExpandedHostingDescriptor {
        OriginalExpandedHostingDescriptorBuilder.makeDescriptor(from: OriginalIslandGeometryInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 947),
            safeAreaTopInset: 32,
            displayState: .expanded,
            compactIntrinsicWidth: 0,
            sessionCount: 1,
            maxExpandedWidth: 640,
            maxExpandedHeight: 560
        ))!
    }

    private var compactRenderList: IslandSurfaceRenderList {
        let session = AgentSession(
            id: "root-session",
            source: "codex",
            cwd: "/work/root",
            originalStatus: .processing,
            repoName: "root"
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

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalUnifiedIslandRootView.swift")
    }

    private var platformCompositionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitPlatformComposition.swift")
    }

    private var rendererSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/MyVibeIslandAppKitOriginalUnifiedHostingRenderer.swift")
    }

    private var expandedSessionsListSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalExpandedSessionsListView.swift")
    }

    private func mirroredDescendants(of value: Any) -> [Any] {
        var result: [Any] = []
        for child in Mirror(reflecting: value).children {
            result.append(child.value)
            result.append(contentsOf: mirroredDescendants(of: child.value))
        }
        return result
    }
}

private extension OriginalCompactHostingDescriptor {
    func replacingCompletionFlashTick(_ tick: Int) -> Self {
        Self(
            displayClass: displayClass,
            contentPlan: contentPlan,
            sessionInputs: [],
            compactLayoutPlan: compactLayoutPlan,
            rightPresentationPlan: rightPresentationPlan,
            rootLayoutPlan: rootLayoutPlan,
            layoutMode: layoutMode,
            isMinimized: isMinimized,
            surfaceSize: surfaceSize,
            displayState: displayState,
            completionFlashTick: tick
        )
    }
}
