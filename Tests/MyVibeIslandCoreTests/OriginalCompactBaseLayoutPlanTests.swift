import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactBaseLayoutPlanTests: XCTestCase {
    func testLayoutModeRawValuesMatchOriginalSemantics() throws {
        XCTAssertEqual(OriginalNotchLayoutMode.compact.rawValue, 0)
        XCTAssertEqual(OriginalNotchLayoutMode.normal.rawValue, 1)
        XCTAssertEqual(try JSONEncoder().encode(OriginalNotchLayoutMode.compact), Data("0".utf8))
        XCTAssertEqual(try JSONEncoder().encode(OriginalNotchLayoutMode.normal), Data("1".utf8))
    }

    func testCompleteLayoutMatrix() {
        for displayClass in OriginalCompactBaseLayoutPlan.DisplayClass.allCases {
            for layoutMode in OriginalNotchLayoutMode.allCases {
                for isMinimized in [false, true] {
                    for hasActionableCount in [false, true] {
                        for hasSessions in [false, true] {
                            let plan = resolve(
                                displayClass: displayClass,
                                layoutMode: layoutMode,
                                isMinimized: isMinimized,
                                hasActionableCount: hasActionableCount,
                                hasSessions: hasSessions
                            )

                            let compact = isMinimized || layoutMode == .compact
                            XCTAssertEqual(plan.usesCompactArrangement, compact)
                            XCTAssertEqual(
                                plan.iconKind,
                                isMinimized ? .pixelStatusIconCompact : .pixelStatusIcon
                            )
                            XCTAssertEqual(
                                plan.iconFrame,
                                DisplaySize(width: isMinimized ? 20 : 32, height: 20)
                            )
                            XCTAssertEqual(plan.rootHorizontalSpacing, displayClass == .physicalNotch ? 6 : 0)
                            XCTAssertEqual(plan.rightInnerSpacing, compact ? 2 : 6)

                            switch displayClass {
                            case .physicalNotch:
                                XCTAssertEqual(
                                    plan.statusRegionWidth,
                                    isMinimized ? 22 : layoutMode == .compact ? 36 : 100
                                )
                                XCTAssertEqual(plan.titleVisible, !compact)
                                XCTAssertFalse(plan.titleFlexesToMaximumWidth)
                                XCTAssertEqual(plan.leadingPadding, compact ? 2 : 8)
                                XCTAssertNil(plan.titleTrailingPadding)
                                XCTAssertEqual(plan.centerNotchWidth, 224)
                                XCTAssertEqual(
                                    plan.rightRegionWidth,
                                    isMinimized ? 22 : layoutMode == .compact
                                        ? hasActionableCount ? 36 : 18
                                        : 100
                                )
                                XCTAssertEqual(plan.rightTrailingPadding, compact ? 2 : 8)
                                XCTAssertEqual(
                                    plan.titleStyle,
                                    .init(
                                        fontSize: 10,
                                        fontWeight: .medium,
                                        fontDesign: .monospaced,
                                        foregroundOpacity: 0.9,
                                        lineLimit: 1,
                                        truncationMode: .tail
                                    )
                                )

                            case .nonNotched:
                                XCTAssertEqual(
                                    plan.statusRegionWidth,
                                    isMinimized ? 28 : layoutMode == .compact ? 36 : 60
                                )
                                XCTAssertTrue(plan.titleVisible)
                                XCTAssertTrue(plan.titleFlexesToMaximumWidth)
                                XCTAssertNil(plan.leadingPadding)
                                XCTAssertEqual(plan.titleTrailingPadding, 8)
                                XCTAssertNil(plan.centerNotchWidth)
                                XCTAssertNil(plan.rightRegionWidth)
                                XCTAssertEqual(plan.rightTrailingPadding, 8)
                                XCTAssertEqual(
                                    plan.titleStyle,
                                    .init(
                                        fontSize: 11,
                                        fontWeight: .medium,
                                        fontDesign: .monospaced,
                                        foregroundOpacity: hasSessions ? 1 : 0.6,
                                        lineLimit: hasSessions ? 1 : nil,
                                        truncationMode: hasSessions ? .tail : nil
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    func testIconGlowChangesOnlyWithMinimizedState() {
        XCTAssertEqual(
            resolve(isMinimized: true).innerGlows,
            [
                .init(opacity: 0.5, radius: 2),
                .init(opacity: 0.25, radius: 6),
            ]
        )
        XCTAssertEqual(
            resolve(isMinimized: false).innerGlows,
            [
                .init(opacity: 0.5, radius: 3),
                .init(opacity: 0.2, radius: 8),
            ]
        )
    }

    func testPhysicalNotchWidthUsesOnlyTheConfirmedLowerBound() {
        XCTAssertEqual(
            resolve(screenNotchWidth: -100, notchWidthOffset: -25).centerNotchWidth,
            40
        )
        XCTAssertEqual(
            resolve(screenNotchWidth: -100, notchWidthOffset: 175).centerNotchWidth,
            75
        )
        XCTAssertEqual(
            resolve(screenNotchWidth: 12, notchWidthOffset: -3).centerNotchWidth,
            40
        )
    }

    func testCompletionFlashProgressIsNotClamped() {
        XCTAssertEqual(
            resolve(completionFlashProgress: -2).completionFlash,
            .init(
                glows: [
                    .init(opacity: -2, radius: 7),
                    .init(opacity: -1.2, radius: 13),
                ],
                scale: 0.64
            )
        )
        XCTAssertEqual(
            resolve(completionFlashProgress: 10).completionFlash,
            .init(
                glows: [
                    .init(opacity: 10, radius: 7),
                    .init(opacity: 6, radius: 13),
                ],
                scale: 2.8
            )
        )
    }

    func testPlanIsCodableEquatableAndSendableWithoutInfinitySentinel() throws {
        let plan = resolve(displayClass: .nonNotched, hasSessions: false)
        let decoded = try JSONDecoder().decode(
            OriginalCompactBaseLayoutPlan.self,
            from: JSONEncoder().encode(plan)
        )

        XCTAssertEqual(decoded, plan)
        XCTAssertTrue(decoded.titleFlexesToMaximumWidth)
        XCTAssertNil(decoded.centerNotchWidth)
        XCTAssertNil(decoded.rightRegionWidth)
        assertSendable(plan)
    }

    private func resolve(
        displayClass: OriginalCompactBaseLayoutPlan.DisplayClass = .physicalNotch,
        layoutMode: OriginalNotchLayoutMode = .normal,
        isMinimized: Bool = false,
        hasActionableCount: Bool = false,
        hasSessions: Bool = true,
        screenNotchWidth: Double = 224,
        notchWidthOffset: Double = 0,
        completionFlashProgress: Double = 0
    ) -> OriginalCompactBaseLayoutPlan {
        OriginalCompactBaseLayoutPlan.resolve(
            displayClass: displayClass,
            layoutMode: layoutMode,
            isMinimized: isMinimized,
            hasActionableCount: hasActionableCount,
            hasSessions: hasSessions,
            screenNotchWidth: screenNotchWidth,
            notchWidthOffset: notchWidthOffset,
            completionFlashProgress: completionFlashProgress
        )
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
