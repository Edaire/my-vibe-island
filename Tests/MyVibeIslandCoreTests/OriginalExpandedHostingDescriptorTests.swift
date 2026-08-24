import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalExpandedHostingDescriptorTests: XCTestCase {
    func testDescriptorPreservesObservedGeometry() {
        let descriptor = descriptorWithObservedGeometry()

        XCTAssertEqual(
            descriptor.geometry.panelFrame,
            DisplayFrame(x: 416, y: 402, width: 680, height: 580)
        )
        XCTAssertEqual(
            descriptor.geometry.surfaceFrame,
            DisplayFrame(x: 20, y: 176, width: 640, height: 404)
        )
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 404))
        XCTAssertEqual(descriptor.hostSize, DisplaySize(width: 680, height: 580))
        XCTAssertEqual(descriptor.rootLayoutPlan.outerHorizontalInset, 19)
        XCTAssertEqual(descriptor.rootLayoutPlan.shape.topCornerRadius, 19)
        XCTAssertEqual(descriptor.rootLayoutPlan.shape.bottomCornerRadius, 24)
        XCTAssertEqual(
            descriptor.rootLayoutPlan.shadow,
            .init(colorKind: .black, opacity: 0.70, radius: 6, x: 0, y: 0)
        )
        XCTAssertEqual(descriptor.rootLayoutPlan.topSeamHorizontalInset, 19)
        XCTAssertEqual(descriptor.contentPlan, .empty)
        assertSendable(descriptor)
    }

    func testContentPlanCarriesTypedRowsAndHighlightedID() {
        let row = OriginalExpandedSessionRow(
            preview: SessionCardPreview(session: AgentSession(
                id: "session-1",
                source: "codex",
                cwd: "/work/project",
                originalStatus: .processing,
                repoName: "project"
            )),
            modelLabel: "gpt-5",
            repositoryLabel: "project"
        )
        let plan = OriginalExpandedContentPlan(
            sessionRows: [row],
            highlightedID: "session-1"
        )

        XCTAssertEqual(plan.sessionRows, [row])
        XCTAssertEqual(plan.highlightedID, "session-1")
        assertSendable(plan)
    }

    func testExpandedDisplayTitleMatchesPreviewDisplayTitle() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            safeTitle: nil,
            customTitle: nil,
            desktopTitle: nil,
            aiTitle: nil,
            summary: "Conversation summary",
            firstUserMessage: "Build the session card",
            lastUserMessage: "Show the real session"
        )
        let preview = SessionCardPreview(session: session)
        let row = OriginalExpandedSessionRow(session: session, preview: preview)

        XCTAssertEqual(row.expandedDisplayTitle, preview.displayTitle)
        XCTAssertEqual(row.expandedDisplayTitle, "Conversation summary")
    }

    func testContentPlanMountsOneCompletionBodyForTheFocusedOrFirstRow() {
        let rows = ["one", "two", "three"].map { id in
            OriginalExpandedSessionRow(preview: SessionCardPreview(session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: .ended,
                lastAssistantMessage: "Completed \(id)"
            )))
        }

        XCTAssertEqual(
            OriginalExpandedContentPlan(sessionRows: rows, highlightedID: "two").completionBodyRowID,
            "two"
        )
        XCTAssertEqual(
            OriginalExpandedContentPlan(sessionRows: rows).completionBodyRowID,
            "one"
        )
        XCTAssertNil(OriginalExpandedContentPlan.empty.completionBodyRowID)
    }

    func testHostSizeIsTheFixedPanelSizeInsteadOfTheGeometryPanelFrame() {
        let descriptor = OriginalExpandedHostingDescriptor(
            geometry: OriginalIslandGeometry(
                panelFrame: DisplayFrame(x: 0, y: 0, width: 1, height: 2),
                surfaceFrame: DisplayFrame(x: 20, y: 176, width: 640, height: 404)
            ),
            rootLayoutPlan: expandedRootLayoutPlan
        )

        XCTAssertEqual(descriptor.hostSize, OriginalIslandGeometryResolver.panelSize)
    }

    func testBuilderRejectsNonExpandedDisplayStates() {
        for displayState in [
            OriginalIslandDisplayState.compact,
            .peek,
        ] {
            XCTAssertNil(
                OriginalExpandedHostingDescriptorBuilder.makeDescriptor(from: input(
                    displayState: displayState
                ))
            )
        }
    }

    func testBuilderRejectsInvalidOrOversizedExpandedLimits() {
        let invalidLimits: [(Double, Double)] = [
            (0, 560),
            (-1, 560),
            (640, 0),
            (640, -1),
            (640.1, 560),
            (640, 560.1),
        ]

        for (maxExpandedWidth, maxExpandedHeight) in invalidLimits {
            XCTAssertNil(
                OriginalExpandedHostingDescriptorBuilder.makeDescriptor(from: input(
                    maxExpandedWidth: maxExpandedWidth,
                    maxExpandedHeight: maxExpandedHeight
                ))
            )
        }
    }

    func testBuilderPassesGeometryThroughOriginalIslandGeometryResolver() throws {
        let inputs = [
            input(sessionCount: 0),
            input(sessionCount: 1, focusedSpecialSession: true),
            input(sessionCount: 3),
            input(sessionCount: 8),
            input(measuredContentHeight: 700),
            input(
                measuredContentHeight: 300,
                maxExpandedWidth: 600,
                maxExpandedHeight: 380
            ),
        ]
        let resolver = OriginalIslandGeometryResolver()

        for input in inputs {
            let descriptor = try XCTUnwrap(
                OriginalExpandedHostingDescriptorBuilder.makeDescriptor(from: input)
            )

            XCTAssertEqual(descriptor.geometry, resolver.resolve(input))
        }
    }

    func testExpandedDescriptorTypesAreConsumedOnlyByTheDedicatedAppKitRenderer() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourcesURL.path)
            .filter { $0.hasSuffix(".swift") }
            .filter { $0 != "MyVibeIslandCore/Runtime/OriginalExpandedHostingDescriptor.swift" }
        let descriptorTypes = [
            "OriginalExpandedHostingDescriptor",
            "OriginalExpandedHostingDescriptorBuilder",
            "OriginalExpandedContentPlan",
        ]

        let allowedConsumers = Set([
            "MyVibeIslandApp/MyVibeIslandAppKitPlatformComposition.swift",
            "MyVibeIslandApp/MyVibeIslandAppKitOriginalUnifiedHostingRenderer.swift",
            "MyVibeIslandApp/OriginalExpandedHostingDescriptorAdapter.swift",
            "MyVibeIslandApp/OriginalExpandedSessionsListView.swift",
            "MyVibeIslandApp/OriginalExpandedSessionCardView.swift",
            "MyVibeIslandApp/OriginalSwitcherSurfaceView.swift",
            "MyVibeIslandApp/OriginalUnifiedIslandHostingModel.swift",
            "MyVibeIslandApp/OriginalUnifiedIslandRootView.swift",
        ])

        XCTAssertFalse(sourceFiles.isEmpty)
        for file in sourceFiles {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(file),
                encoding: .utf8
            )
            for descriptorType in descriptorTypes {
                if source.contains(descriptorType) {
                    XCTAssertTrue(allowedConsumers.contains(file), "\(file): \(descriptorType)")
                }
            }
        }
    }

    private func input(
        displayState: OriginalIslandDisplayState = .expanded,
        measuredContentHeight: Double = 0,
        sessionCount: Int = 0,
        focusedSpecialSession: Bool = false,
        maxExpandedWidth: Double = 640,
        maxExpandedHeight: Double = 560
    ) -> OriginalIslandGeometryInput {
        OriginalIslandGeometryInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 947),
            displayState: displayState,
            compactIntrinsicWidth: 100,
            measuredContentHeight: measuredContentHeight,
            sessionCount: sessionCount,
            focusedSpecialSession: focusedSpecialSession,
            maxExpandedWidth: maxExpandedWidth,
            maxExpandedHeight: maxExpandedHeight
        )
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var expandedRootLayoutPlan: OriginalRootSurfaceLayoutPlan {
        OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .expanded,
            isHovering: false,
            safeAreaTopInset: 0,
            leftStatusSlotWidth: 36,
            rightStatusSlotWidth: 36
        )
    }

    private func descriptorWithObservedGeometry() -> OriginalExpandedHostingDescriptor {
        OriginalExpandedHostingDescriptor(
            geometry: OriginalIslandGeometry(
                panelFrame: DisplayFrame(x: 416, y: 402, width: 680, height: 580),
                surfaceFrame: DisplayFrame(x: 20, y: 176, width: 640, height: 404)
            ),
            rootLayoutPlan: expandedRootLayoutPlan
        )
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
