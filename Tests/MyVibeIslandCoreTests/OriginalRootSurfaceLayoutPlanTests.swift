import XCTest
@testable import MyVibeIslandCore

final class OriginalRootSurfaceLayoutPlanTests: XCTestCase {
    func testCompleteDisplayHoverSafeAreaAndSlotAsymmetryMatrix() {
        let slotPairs: [(left: Double, right: Double)] = [
            (left: 20, right: 44),
            (left: 44, right: 20),
        ]

        for displayState in [
            OriginalIslandDisplayState.compact,
            .peek,
            .expanded,
        ] {
            for isHovering in [false, true] {
                for safeAreaTopInset in [0.0, 24.0] {
                    for slots in slotPairs {
                        let plan = OriginalRootSurfaceLayoutPlan.resolve(
                            displayState: displayState,
                            isHovering: isHovering,
                            safeAreaTopInset: safeAreaTopInset,
                            leftStatusSlotWidth: slots.left,
                            rightStatusSlotWidth: slots.right
                        )

                        XCTAssertEqual(plan.rootStackSpacing, 0)
                        XCTAssertEqual(plan.topSeamHeight, 1)
                        XCTAssertEqual(plan.topSeamHorizontalInset, plan.shape.topCornerRadius)
                        XCTAssertEqual(
                            plan.shape,
                            OriginalNotchShapeParametersResolver().resolve(displayState)
                        )
                        XCTAssertEqual(
                            plan.hoverScale,
                            isHovering && displayState != .expanded ? 1.02 : 1
                        )
                        XCTAssertEqual(
                            plan.physicalHorizontalOffset,
                            0
                        )

                        switch displayState {
                        case .compact:
                            XCTAssertEqual(plan.outerHorizontalInset, 10)
                            XCTAssertEqual(plan.innerHorizontalBottomPadding, 0)
                            XCTAssertEqual(
                                plan.shadow,
                                isHovering
                                    ? .init(colorKind: .black, opacity: 0.70, radius: 6, x: 0, y: 0)
                                    : .init(colorKind: .clear, opacity: 0, radius: 0, x: 0, y: 0)
                            )

                        case .peek:
                            XCTAssertEqual(plan.outerHorizontalInset, 12)
                            XCTAssertEqual(plan.innerHorizontalBottomPadding, 4)
                            XCTAssertEqual(
                                plan.shadow,
                                .init(colorKind: .black, opacity: 0.62, radius: 12, x: 0, y: 4)
                            )

                        case .expanded:
                            XCTAssertEqual(plan.outerHorizontalInset, 19)
                            XCTAssertEqual(plan.innerHorizontalBottomPadding, 4)
                            XCTAssertEqual(
                                plan.shadow,
                                .init(colorKind: .black, opacity: 0.70, radius: 6, x: 0, y: 0)
                            )
                        }
                    }
                }
            }
        }
    }

    func testTopSeamHorizontalInsetUsesTopCornerRadiusMatrix() {
        let cases: [(OriginalIslandDisplayState, Double)] = [
            (.compact, 6),
            (.peek, 10),
            (.expanded, 19),
        ]

        for (displayState, expectedInset) in cases {
            let plan = OriginalRootSurfaceLayoutPlan.resolve(
                displayState: displayState,
                isHovering: false,
                safeAreaTopInset: 0,
                leftStatusSlotWidth: 24,
                rightStatusSlotWidth: 24
            )

            XCTAssertEqual(plan.topSeamHorizontalInset, expectedInset)
        }
    }

    func testPhysicalHorizontalOffsetDoesNotMoveTheIslandWhenSlotWidthsDiffer() {
        XCTAssertEqual(
            OriginalRootSurfaceLayoutPlan.resolve(
                displayState: .compact,
                isHovering: false,
                safeAreaTopInset: 0.25,
                leftStatusSlotWidth: 13.5,
                rightStatusSlotWidth: 10
            ).physicalHorizontalOffset,
            0
        )
    }

    func testExpandedRootUsesRecoveredNineteenPointInset() {
        let plan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .expanded,
            isHovering: false,
            safeAreaTopInset: 0,
            leftStatusSlotWidth: 0,
            rightStatusSlotWidth: 0
        )

        XCTAssertEqual(plan.outerHorizontalInset, 19)
    }

    func testCodableRoundTripAndExactFieldShape() throws {
        let plan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .peek,
            isHovering: true,
            safeAreaTopInset: 24,
            leftStatusSlotWidth: 20,
            rightStatusSlotWidth: 44
        )
        let encoded = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(
            OriginalRootSurfaceLayoutPlan.self,
            from: encoded
        )

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(
            try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? NSDictionary),
            [
                "rootStackSpacing": 0.0,
                "outerHorizontalInset": 12.0,
                "innerHorizontalBottomPadding": 4.0,
                "shape": [
                    "topCornerRadius": 10.0,
                    "bottomCornerRadius": 20.0,
                ],
                "shadow": [
                    "colorKind": "black",
                    "opacity": 0.62,
                    "radius": 12.0,
                    "x": 0.0,
                    "y": 4.0,
                ],
                "hoverScale": 1.02,
                "physicalHorizontalOffset": 0.0,
                "topSeamHeight": 1.0,
                "topSeamHorizontalInset": 10.0,
            ] as NSDictionary
        )
        assertSendable(plan)
    }

    func testDecodingIgnoresConflictingTopSeamHorizontalInset() throws {
        let data = Data(#"""
        {
          "rootStackSpacing": 0,
          "outerHorizontalInset": 12,
          "innerHorizontalBottomPadding": 4,
          "shape": {
            "topCornerRadius": 10,
            "bottomCornerRadius": 20
          },
          "shadow": {
            "colorKind": "black",
            "opacity": 0.62,
            "radius": 12,
            "x": 0,
            "y": 4
          },
          "hoverScale": 1.02,
          "physicalHorizontalOffset": 12,
          "topSeamHeight": 1,
          "topSeamHorizontalInset": -999
        }
        """#.utf8)

        let plan = try JSONDecoder().decode(OriginalRootSurfaceLayoutPlan.self, from: data)

        XCTAssertEqual(plan.shape.topCornerRadius, 10)
        XCTAssertEqual(plan.topSeamHorizontalInset, 10)
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
