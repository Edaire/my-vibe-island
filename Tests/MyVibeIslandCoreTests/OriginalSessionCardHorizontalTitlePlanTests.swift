import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardHorizontalTitlePlanTests: XCTestCase {
    func testResolveUsesFixedSystemTitleStyle() {
        let plan = resolve()

        XCTAssertEqual(plan.systemFontSize, 12)
        XCTAssertEqual(plan.systemFontWeight, .medium)
        XCTAssertEqual(plan.foreground, .white(opacity: 0.7))
    }

    func testResolveAlwaysStartsWithUnmodifiedBaseSegment() {
        let plan = resolve(baseTitle: "  base title  ")

        XCTAssertEqual(
            plan.segments,
            [.init(prefix: "", value: "  base title  ", foreground: nil)]
        )
        XCTAssertEqual(plan.concatenatedText, "  base title  ")
    }

    func testModelSegmentRequiresShowFlagAndNonNilLabel() {
        let cases: [(show: Bool, label: String?, expectedModel: Bool)] = [
            (false, nil, false),
            (false, "model", false),
            (true, nil, false),
            (true, "model", true),
        ]

        for testCase in cases {
            let plan = resolve(
                showModelInPanel: testCase.show,
                modelLabel: testCase.label
            )
            let expectedSegments: [OriginalSessionCardHorizontalTitlePlan.Segment] =
                testCase.expectedModel
                    ? [
                        .init(prefix: "", value: "base", foreground: nil),
                        .init(
                            prefix: " ⎇ ",
                            value: "model",
                            foreground: .white(opacity: 0.5)
                        ),
                    ]
                    : [.init(prefix: "", value: "base", foreground: nil)]

            XCTAssertEqual(plan.segments, expectedSegments)
        }
    }

    func testRepositorySegmentRequiresOnlyNonNilLabel() {
        XCTAssertEqual(
            resolve(repositoryLabel: nil).segments,
            [.init(prefix: "", value: "base", foreground: nil)]
        )
        XCTAssertEqual(
            resolve(repositoryLabel: "repository").segments,
            [
                .init(prefix: "", value: "base", foreground: nil),
                .init(prefix: " · ", value: "repository", foreground: nil),
            ]
        )
    }

    func testBothOptionalSegmentsUseExactOrderPrefixesValuesAndOverrides() {
        let plan = resolve(
            baseTitle: "base",
            showModelInPanel: true,
            modelLabel: "  model  ",
            repositoryLabel: " repository "
        )

        XCTAssertEqual(
            plan.segments,
            [
                .init(prefix: "", value: "base", foreground: nil),
                .init(
                    prefix: " ⎇ ",
                    value: "  model  ",
                    foreground: .white(opacity: 0.5)
                ),
                .init(prefix: " · ", value: " repository ", foreground: nil),
            ]
        )
        XCTAssertEqual(plan.concatenatedText, "base ⎇   model   ·  repository ")
    }

    func testNonNilEmptyLabelsStillProduceSegmentsWithoutTrimming() {
        let shown = resolve(
            showModelInPanel: true,
            modelLabel: "",
            repositoryLabel: ""
        )

        XCTAssertEqual(
            shown.segments,
            [
                .init(prefix: "", value: "base", foreground: nil),
                .init(prefix: " ⎇ ", value: "", foreground: .white(opacity: 0.5)),
                .init(prefix: " · ", value: "", foreground: nil),
            ]
        )
        XCTAssertEqual(shown.concatenatedText, "base ⎇  · ")

        let hidden = resolve(
            showModelInPanel: false,
            modelLabel: "",
            repositoryLabel: ""
        )
        XCTAssertEqual(
            hidden.segments,
            [
                .init(prefix: "", value: "base", foreground: nil),
                .init(prefix: " · ", value: "", foreground: nil),
            ]
        )
        XCTAssertEqual(hidden.concatenatedText, "base · ")
    }

    func testModelsAreSendable() {
        let plan = resolve(
            showModelInPanel: true,
            modelLabel: "model",
            repositoryLabel: "repository"
        )

        assertSendable(plan)
        assertSendable(plan.segments[0])
        assertSendable(plan.foreground)
        assertSendable(plan.systemFontWeight)
    }

    private func resolve(
        baseTitle: String = "base",
        showModelInPanel: Bool = false,
        modelLabel: String? = nil,
        repositoryLabel: String? = nil
    ) -> OriginalSessionCardHorizontalTitlePlan {
        OriginalSessionCardHorizontalTitlePlan.resolve(
            baseTitle: baseTitle,
            showModelInPanel: showModelInPanel,
            modelLabel: modelLabel,
            repositoryLabel: repositoryLabel
        )
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var declarationURL: URL {
        packageRootURL
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime")
            .appendingPathComponent("OriginalSessionCardHorizontalTitlePlan.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
