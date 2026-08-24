import Foundation
import MyVibeIslandCore
import XCTest

final class OriginalPeekStaticSliceTests: XCTestCase {
    func testNotificationHasOnlyTheFrozenFiveFieldsAndRoundTripsCodable() throws {
        let notification = OriginalPeekNotification(
            id: "n-1",
            title: "Done",
            detail: "Task completed",
            provider: .anthropic,
            level: .info
        )

        XCTAssertEqual(
            Set(Mirror(reflecting: notification).children.compactMap(\.label)),
            ["id", "title", "detail", "provider", "level"]
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalPeekNotification.self,
                from: JSONEncoder().encode(notification)
            ),
            notification
        )
    }

    func testProviderLevelAndTransientCaseSetsAreFrozen() {
        XCTAssertEqual(
            OriginalPeekProvider.allCases,
            [.anthropic, .openai, .google, .zhipu, .kimi]
        )
        XCTAssertEqual(
            OriginalPeekLevel.allCases,
            [.info, .warning, .critical]
        )
        XCTAssertEqual(
            OriginalPeekTransientKind.allCases,
            [.taskComplete, .statusWarning]
        )
    }

    func testSupplementalContentOnlyEmitsForPeek() {
        let notification = OriginalPeekNotification(
            id: "n-1",
            title: "Done",
            detail: "Task completed",
            provider: nil,
            level: .info
        )

        XCTAssertEqual(
            OriginalPeekSupplementalContentPlan.resolve(
                .peek(notification, kind: .taskComplete)
            ),
            .row(notification)
        )
        XCTAssertEqual(OriginalPeekSupplementalContentPlan.resolve(.blocking), .empty)
        XCTAssertEqual(OriginalPeekSupplementalContentPlan.resolve(.transient), .empty)
        XCTAssertEqual(OriginalPeekSupplementalContentPlan.resolve(.closed), .empty)
        XCTAssertEqual(OriginalPeekSupplementalContentPlan.resolve(.manualExpanded), .empty)
    }

    func testPeekDisplayStateAndSupplementalRowRoundTripCodable() throws {
        let notification = OriginalPeekNotification(
            id: "n-1",
            title: "Done",
            detail: "Task completed",
            provider: .kimi,
            level: .critical
        )
        let state = OriginalPeekDisplayState.peek(notification, kind: .statusWarning)
        let plan = OriginalPeekSupplementalContentPlan.row(notification)

        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalPeekDisplayState.self,
                from: JSONEncoder().encode(state)
            ),
            state
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalPeekSupplementalContentPlan.self,
                from: JSONEncoder().encode(plan)
            ),
            plan
        )
    }

    func testPeekDescriptorUsesCurrentPhysicalSizeAndScreenClamp() {
        let descriptor = OriginalPeekHostingDescriptor(
            compactSurfaceSize: DisplaySize(width: 239, height: 33),
            screenWidth: 1512
        )
        XCTAssertEqual(descriptor.maxExpandedWidth, 640)
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 327, height: 71))
        XCTAssertEqual(descriptor.hostSize, DisplaySize(width: 680, height: 580))
        XCTAssertEqual(descriptor.rootLayoutPlan.outerHorizontalInset, 12)
        XCTAssertEqual(descriptor.rootLayoutPlan.innerHorizontalBottomPadding, 4)
        XCTAssertEqual(descriptor.rootLayoutPlan.shape.topCornerRadius, 10)
        XCTAssertEqual(descriptor.rootLayoutPlan.shape.bottomCornerRadius, 20)
        XCTAssertEqual(descriptor.rootLayoutPlan.shadow.opacity, 0.62)
        XCTAssertEqual(descriptor.rootLayoutPlan.shadow.radius, 12)
        XCTAssertEqual(descriptor.rootLayoutPlan.shadow.y, 4)
        XCTAssertEqual(descriptor.rootLayoutPlan.topSeamHorizontalInset, 10)
        XCTAssertEqual(
            try? JSONDecoder().decode(
                OriginalPeekHostingDescriptor.self,
                from: JSONEncoder().encode(descriptor)
            ),
            descriptor
        )

        XCTAssertEqual(
            OriginalPeekHostingDescriptor(
                compactSurfaceSize: DisplaySize(width: 239, height: 33),
                screenWidth: 300
            ).surfaceSize,
            DisplaySize(width: 260, height: 71)
        )
        XCTAssertEqual(
            OriginalPeekHostingDescriptor(
                compactSurfaceSize: DisplaySize(width: 600, height: 40),
                screenWidth: 1000
            ).surfaceSize,
            DisplaySize(width: 640, height: 78)
        )
    }

    func testPeekDescriptorUsesCustomMaxExpandedWidth() {
        let descriptor = OriginalPeekHostingDescriptor(
            compactSurfaceSize: DisplaySize(width: 239, height: 33),
            screenWidth: 1512,
            maxExpandedWidth: 300
        )

        XCTAssertEqual(descriptor.maxExpandedWidth, 300)
        XCTAssertEqual(descriptor.surfaceSize.width, 300)
    }

    func testPeekSliceDoesNotIntroduceCommercialUsageLimit() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourceURL.path)
            .filter { $0.contains("OriginalPeek") }
        let forbidden = [
            "usageLimit",
            "usageThreshold",
            "usageReset",
            "license",
            "checkout",
            "subscription",
            "account",
            "telemetry",
            "Sentry",
        ]

        for file in sourceFiles {
            let source = try String(
                contentsOf: sourceURL.appendingPathComponent(file),
                encoding: .utf8
            )
            for forbiddenTerm in forbidden {
                XCTAssertFalse(source.contains(forbiddenTerm), "\(file): \(forbiddenTerm)")
            }
        }
    }
}
