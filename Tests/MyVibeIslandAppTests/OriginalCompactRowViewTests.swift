import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalCompactRowViewTests: XCTestCase {
    func testViewStoresExactlyTheAcceptedInputs() {
        let fixture = makeFixture(
            displayClass: .physicalNotch,
            layoutMode: .normal,
            isMinimized: false,
            sessions: [session(status: .processing, currentTool: "Read")]
        )
        let view = fixture.view(completionFlashProgress: 0.4)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), [
            "displayClass",
            "contentPlan",
            "layoutPlan",
            "rightPresentationPlan",
            "layoutMode",
            "isMinimized",
            "completionFlashProgress",
        ])
        XCTAssertEqual(fields["displayClass"] as? OriginalCompactBaseLayoutPlan.DisplayClass, .physicalNotch)
        XCTAssertEqual(fields["contentPlan"] as? OriginalCompactContentPlan, fixture.contentPlan)
        XCTAssertEqual(fields["layoutPlan"] as? OriginalCompactBaseLayoutPlan, fixture.layoutPlan)
        XCTAssertEqual(
            fields["rightPresentationPlan"] as? OriginalCompactRightPresentationPlan,
            fixture.rightPresentationPlan
        )
        XCTAssertEqual(fields["layoutMode"] as? OriginalNotchLayoutMode, .normal)
        XCTAssertEqual(fields["isMinimized"] as? Bool, false)
        XCTAssertEqual(fields["completionFlashProgress"] as? Double, 0.4)
    }

    func testPhysicalNormalRendersStatusTitleNotchAndSessionsWithAcceptedFrames() throws {
        let fixture = makeFixture(
            displayClass: .physicalNotch,
            layoutMode: .normal,
            isMinimized: false,
            sessions: [session(status: .processing, currentTool: "Read")]
        )

        try assertRenderMatchesExpected(fixture, expected: physicalExpected(fixture))
    }

    func testPhysicalCompactActionableRendersWithoutTitle() throws {
        let fixture = makeFixture(
            displayClass: .physicalNotch,
            layoutMode: .compact,
            isMinimized: false,
            sessions: [
                session(status: .waitingForApproval),
                session(status: .question),
            ]
        )

        try assertRenderMatchesExpected(fixture, expected: physicalExpected(fixture))
    }

    func testPhysicalMinimizedEmptyRendersAcceptedEmptyRightRegion() throws {
        let fixture = makeFixture(
            displayClass: .physicalNotch,
            layoutMode: .normal,
            isMinimized: true,
            sessions: []
        )

        try assertRenderMatchesExpected(fixture, expected: physicalExpected(fixture))
    }

    func testNonNotchedNormalActionableRendersFlexibleTitleAndUnframedRightWrapper() throws {
        let fixture = makeFixture(
            displayClass: .nonNotched,
            layoutMode: .normal,
            isMinimized: false,
            sessions: [
                session(status: .waitingForInput, customTitle: "Frozen title"),
                session(status: .waitingForApproval),
            ]
        )

        try assertRenderMatchesExpected(fixture, expected: nonNotchedExpected(fixture))
    }

    func testNonNotchedCompactEmptyRendersDefaultTitleAndEmptyRightWrapper() throws {
        let fixture = makeFixture(
            displayClass: .nonNotched,
            layoutMode: .compact,
            isMinimized: false,
            sessions: []
        )

        try assertRenderMatchesExpected(fixture, expected: nonNotchedExpected(fixture))
    }

    func testNonNotchedMinimizedActionableUsesMinimizedStatusAndAcceptedPadding() throws {
        let fixture = makeFixture(
            displayClass: .nonNotched,
            layoutMode: .normal,
            isMinimized: true,
            sessions: [session(status: .question, customTitle: "Needs input")]
        )

        try assertRenderMatchesExpected(fixture, expected: nonNotchedExpected(fixture))
    }

    func testProductionSourceLocksLeafReuseHierarchyValuesAndModifierOrder() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let requiredInOrder = [
            "public struct OriginalCompactRowView: View {",
            "public let displayClass: OriginalCompactBaseLayoutPlan.DisplayClass",
            "public let contentPlan: OriginalCompactContentPlan",
            "public let layoutPlan: OriginalCompactBaseLayoutPlan",
            "public let rightPresentationPlan: OriginalCompactRightPresentationPlan",
            "public let layoutMode: OriginalNotchLayoutMode",
            "public let isMinimized: Bool",
            "public let completionFlashProgress: Double",
            "switch displayClass {",
            "case .physicalNotch:",
            "HStack(alignment: .center, spacing: CGFloat(layoutPlan.rootHorizontalSpacing))",
            "OriginalCompactStatusContainerView(",
            "status: contentPlan.status,",
            "isMinimized: isMinimized,",
            "completionFlashProgress: completionFlashProgress",
            "if layoutPlan.titleVisible, let title = contentPlan.title",
            "OriginalCompactTitleView(plan: title, style: layoutPlan.titleStyle)",
            ".padding(.leading, CGFloat(leadingPadding))",
            ".frame(width: CGFloat(layoutPlan.statusRegionWidth), alignment: .leading)",
            "Spacer().frame(minWidth: CGFloat(centerNotchWidth))",
            "if let rightRegionWidth = layoutPlan.rightRegionWidth",
            "HStack(alignment: .center, spacing: CGFloat(layoutPlan.rightInnerSpacing))",
            "OriginalCompactRightPresentationView(plan: rightPresentationPlan)",
            ".padding(.trailing, CGFloat(layoutPlan.rightTrailingPadding))",
            ".frame(width: CGFloat(rightRegionWidth), alignment: .trailing)",
            "case .nonNotched:",
            "HStack(alignment: .center, spacing: CGFloat(layoutPlan.rootHorizontalSpacing))",
            "OriginalCompactStatusContainerView(",
            ".frame(width: CGFloat(layoutPlan.statusRegionWidth), alignment: .center)",
            "if let title = contentPlan.title",
            "OriginalCompactTitleView(plan: title, style: layoutPlan.titleStyle)",
            ".frame(maxWidth: .infinity, alignment: .center)",
            ".padding(.trailing, CGFloat(layoutPlan.titleTrailingPadding!))",
            "HStack(alignment: .center, spacing: CGFloat(layoutPlan.rightInnerSpacing))",
            "OriginalCompactRightPresentationView(plan: rightPresentationPlan)",
            ".padding(.trailing, CGFloat(layoutPlan.rightTrailingPadding))",
            ".animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: isMinimized)",
            ".animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: layoutMode)",
        ]

        var searchStart = source.startIndex
        for required in requiredInOrder {
            let range = try XCTUnwrap(
                source.range(of: required, range: searchStart..<source.endIndex),
                "Missing or out-of-order production source: \(required)"
            )
            searchStart = range.upperBound
        }

        XCTAssertEqual(source.components(separatedBy: "OriginalCompactStatusContainerView(").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: "OriginalCompactTitleView(").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: "OriginalCompactRightPresentationView(").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: ".animation(").count - 1, 2)
    }

    func testProductionSourceForbidsAlternateCompositionAndFallbacks() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for forbidden in [
            "import AppKit",
            "Color.black",
            ".background(",
            "OriginalNotchShape",
            "GeometryReader",
            "NSView",
            "CALayer",
            ".hoverEffect(",
            ".scaleEffect(",
            "withAnimation",
            "Animation.",
            "??",
            "diagnostic",
            ".padding()",
            ".padding(.horizontal",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
    }

    @ViewBuilder
    private func physicalExpected(_ fixture: Fixture) -> some View {
        HStack(alignment: .center, spacing: CGFloat(fixture.layoutPlan.rootHorizontalSpacing)) {
            Group {
                OriginalCompactStatusContainerView(
                    status: fixture.contentPlan.status,
                    isMinimized: fixture.isMinimized,
                    completionFlashProgress: 0
                )
                if fixture.layoutPlan.titleVisible, let title = fixture.contentPlan.title {
                    OriginalCompactTitleView(plan: title, style: fixture.layoutPlan.titleStyle)
                }
            }
            .padding(.leading, CGFloat(fixture.layoutPlan.leadingPadding!))
            .frame(width: CGFloat(fixture.layoutPlan.statusRegionWidth), alignment: .leading)

            Spacer().frame(minWidth: CGFloat(fixture.layoutPlan.centerNotchWidth!))

            HStack(alignment: .center, spacing: CGFloat(fixture.layoutPlan.rightInnerSpacing)) {
                OriginalCompactRightPresentationView(plan: fixture.rightPresentationPlan)
            }
            .padding(.trailing, CGFloat(fixture.layoutPlan.rightTrailingPadding))
            .frame(width: CGFloat(fixture.layoutPlan.rightRegionWidth!), alignment: .trailing)
        }
    }

    @ViewBuilder
    private func nonNotchedExpected(_ fixture: Fixture) -> some View {
        HStack(alignment: .center, spacing: CGFloat(fixture.layoutPlan.rootHorizontalSpacing)) {
            OriginalCompactStatusContainerView(
                status: fixture.contentPlan.status,
                isMinimized: fixture.isMinimized,
                completionFlashProgress: 0
            )
            .frame(width: CGFloat(fixture.layoutPlan.statusRegionWidth), alignment: .center)

            if let title = fixture.contentPlan.title {
                OriginalCompactTitleView(plan: title, style: fixture.layoutPlan.titleStyle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.trailing, CGFloat(fixture.layoutPlan.titleTrailingPadding!))
            }

            HStack(alignment: .center, spacing: CGFloat(fixture.layoutPlan.rightInnerSpacing)) {
                OriginalCompactRightPresentationView(plan: fixture.rightPresentationPlan)
            }
            .padding(.trailing, CGFloat(fixture.layoutPlan.rightTrailingPadding))
        }
    }

    private func assertRenderMatchesExpected<V: View>(
        _ fixture: Fixture,
        expected: V
    ) throws {
        let actual = try render(fixture.view(completionFlashProgress: 0))
        let expected = try render(expected)

        XCTAssertEqual(actual.pixelsWide, expected.pixelsWide)
        XCTAssertEqual(actual.pixelsHigh, expected.pixelsHigh)
        XCTAssertEqual(pngData(actual), pngData(expected))
    }

    private func render<V: View>(_ view: V) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 480, height: 80)
        return try XCTUnwrap(renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)))
    }

    private func pngData(_ image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    private func makeFixture(
        displayClass: OriginalCompactBaseLayoutPlan.DisplayClass,
        layoutMode: OriginalNotchLayoutMode,
        isMinimized: Bool,
        sessions: [OriginalCompactContentPlan.SessionInput]
    ) -> Fixture {
        let contentDisplayClass: OriginalCompactContentPlan.DisplayClass = switch displayClass {
        case .physicalNotch: .physicalNotch
        case .nonNotched: .nonNotched
        }
        let contentPlan = OriginalCompactContentPlan.resolve(
            displayClass: contentDisplayClass,
            sessions: sessions
        )
        let hasActionableCount = contentPlan.rightCount?.source == .actionable
        let layoutPlan = OriginalCompactBaseLayoutPlan.resolve(
            displayClass: displayClass,
            layoutMode: layoutMode,
            isMinimized: isMinimized,
            hasActionableCount: hasActionableCount,
            hasSessions: !sessions.isEmpty,
            screenNotchWidth: 220,
            notchWidthOffset: 4,
            completionFlashProgress: 0
        )
        let rightPresentationPlan = OriginalCompactRightPresentationPlan.resolve(
            rightCount: contentPlan.rightCount,
            usesCompactArrangement: layoutPlan.usesCompactArrangement,
            showsUnreadCompletionOverview: false
        )

        return Fixture(
            displayClass: displayClass,
            contentPlan: contentPlan,
            layoutPlan: layoutPlan,
            rightPresentationPlan: rightPresentationPlan,
            layoutMode: layoutMode,
            isMinimized: isMinimized
        )
    }

    private func session(
        status: OriginalPixelStatusCompact,
        currentTool: String? = nil,
        customTitle: String? = nil
    ) -> OriginalCompactContentPlan.SessionInput {
        OriginalCompactContentPlan.SessionInput(
            status: status,
            currentTool: currentTool,
            customTitle: customTitle
        )
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalCompactRowView.swift")
    }
}

private struct Fixture {
    let displayClass: OriginalCompactBaseLayoutPlan.DisplayClass
    let contentPlan: OriginalCompactContentPlan
    let layoutPlan: OriginalCompactBaseLayoutPlan
    let rightPresentationPlan: OriginalCompactRightPresentationPlan
    let layoutMode: OriginalNotchLayoutMode
    let isMinimized: Bool

    @MainActor
    func view(completionFlashProgress: Double) -> OriginalCompactRowView {
        OriginalCompactRowView(
            displayClass: displayClass,
            contentPlan: contentPlan,
            layoutPlan: layoutPlan,
            rightPresentationPlan: rightPresentationPlan,
            layoutMode: layoutMode,
            isMinimized: isMinimized,
            completionFlashProgress: completionFlashProgress
        )
    }
}
