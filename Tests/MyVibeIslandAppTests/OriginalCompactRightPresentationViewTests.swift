import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalCompactRightPresentationViewTests: XCTestCase {
    func testViewStoresExactlyTheAcceptedPlan() {
        let plan = OriginalCompactRightPresentationPlan.none
        let view = OriginalCompactRightPresentationView(plan: plan)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), ["plan"])
        XCTAssertEqual(fields["plan"] as? OriginalCompactRightPresentationPlan, plan)
    }

    func testNoneBranchHasNoRenderableContent() {
        let renderer = ImageRenderer(
            content: OriginalCompactRightPresentationView(plan: .none)
        )
        renderer.scale = 1

        XCTAssertNil(renderer.cgImage)
    }

    func testActionableBranchRendersTheAcceptedContinuousCapsule() throws {
        let actionable = OriginalCompactRightPresentationPlan.Actionable(
            countText: "8",
            foregroundColor: orange,
            backgroundColor: orangeBackground,
            symbolName: "bell.fill",
            symbolSystemSize: 10,
            countFont: .init(size: 10, weight: .medium, design: .monospaced),
            horizontalPadding: 7,
            verticalPadding: 3,
            capsuleStyle: .continuous
        )
        let actual = try render(
            OriginalCompactRightPresentationView(plan: .actionable(actionable))
        )
        let expected = try render(
            HStack(alignment: .center, spacing: 3) {
                HStack(alignment: .center, spacing: 3) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                    Text("8")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(Color(red: 0.98, green: 0.45, blue: 0.09, opacity: 1))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Color(red: 0.98, green: 0.45, blue: 0.09, opacity: 0.2),
                    in: Capsule(style: .continuous)
                )
            }
        )

        XCTAssertEqual(pngData(actual), pngData(expected))
        let corner: NSColor = try XCTUnwrap(actual.colorAt(x: 0, y: 0))
        let center: NSColor = try XCTUnwrap(
            actual.colorAt(x: actual.pixelsWide / 2, y: actual.pixelsHigh / 2)
        )
        XCTAssertEqual(corner.alphaComponent, 0, accuracy: 0.001)
        XCTAssertGreaterThan(
            center.alphaComponent,
            0
        )
    }

    func testCompletionIndicatorRendersASevenBySevenSquareFromPlanPixels() throws {
        let completion = OriginalCompactRightPresentationPlan.CompletionIndicator(
            color: green,
            frame: .init(width: 7, height: 7),
            glow: .init(color: translucentGreen, radius: 3),
            transition: .init(scaleAnchor: .center, initialScale: 0.00001, combinesOpacity: true)
        )
        let image = try render(
            OriginalCompactRightPresentationView(plan: .completionIndicator(completion))
        )
        let expected = try render(
            HStack(alignment: .center, spacing: 3) {
                Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 1)
                    .frame(width: 7, height: 7)
                    .shadow(
                        color: Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.6),
                        radius: 3,
                        x: 0,
                        y: 0
                    )
                    .transition(
                        .scale(scale: 0.00001, anchor: .center)
                            .combined(with: .opacity)
                    )
            }
        )

        XCTAssertEqual(image.pixelsWide, 7)
        XCTAssertEqual(image.pixelsHigh, 7)
        XCTAssertEqual(pngData(image), pngData(expected))

        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                let color = try XCTUnwrap(
                    image.colorAt(x: x, y: y)?.usingColorSpace(NSColorSpace.sRGB)
                )
                XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.02)
            }
        }
    }

    func testSessionsBranchRendersRuntimeLocalizedSingularLabel() throws {
        try assertSessionsRender(
            countText: "1",
            key: "content.session",
            fallback: "session"
        )
    }

    func testSessionsBranchRendersRuntimeLocalizedPluralLabel() throws {
        try assertSessionsRender(
            countText: "2",
            key: "content.sessions",
            fallback: "sessions"
        )
    }

    func testCompactSessionsBranchOmitsTheLabel() throws {
        let sessions = OriginalCompactRightPresentationPlan.Sessions(
            countText: "4",
            countFont: sessionCountFont,
            countColor: white,
            label: nil
        )
        let actual = try render(
            OriginalCompactRightPresentationView(plan: .sessions(sessions))
        )
        let expected = try render(
            HStack(alignment: .center, spacing: 3) {
                Text("4")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
        )

        XCTAssertEqual(pngData(actual), pngData(expected))
    }

    func testProductionSourceLocksExactViewContractAndConstants() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let requiredInOrder = [
            "public struct OriginalCompactRightPresentationView: View {",
            "public let plan: OriginalCompactRightPresentationPlan",
            "public init(plan: OriginalCompactRightPresentationPlan)",
            "HStack(alignment: .center, spacing: CGFloat(plan.horizontalSpacing))",
            "case .none:",
            "EmptyView()",
            "case let .actionable(actionable):",
            "Image(systemName: actionable.symbolName)",
            ".font(.system(size: CGFloat(actionable.symbolSystemSize)))",
            ".padding(.horizontal, CGFloat(actionable.horizontalPadding))",
            ".padding(.vertical, CGFloat(actionable.verticalPadding))",
            "Capsule(style: .continuous)",
            "case let .completionIndicator(completion):",
            ".frame(",
            "width: CGFloat(completion.frame.width),",
            "height: CGFloat(completion.frame.height)",
            ".shadow(",
            "radius: CGFloat(completion.glow.radius),",
            "x: 0,",
            "y: 0",
            ".transition(",
            ".scale(",
            "scale: CGFloat(completion.transition.initialScale),",
            "anchor: .center",
            ".combined(with: .opacity)",
            "case let .sessions(sessions):",
            "NSLocalizedString(",
            "label.key,",
            "bundle: Bundle.module,",
            "value: label.englishFallback,",
        ]

        var searchStart = source.startIndex
        for required in requiredInOrder {
            let range = try XCTUnwrap(
                source.range(of: required, range: searchStart..<source.endIndex),
                "Missing production source: \(required)"
            )
            searchStart = range.upperBound
        }

        for required in [
            "case .semibold: swiftUIWeight = .semibold",
            "case .medium: swiftUIWeight = .medium",
            "design: .monospaced",
            "Color(",
            "opacity:",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }
    }

    func testProductionSourceForbidsAlternateRenderingAndAnimationMechanisms() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for forbidden in [
            "import AppKit",
            "Circle",
            "CALayer",
            "NSView",
            "NSBezierPath",
            ".border(",
            ".stroke(",
            ".overlay(",
            ".animation(",
            "withAnimation",
            "Animation.",
            "Timer",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
    }

    private func assertSessionsRender(
        countText: String,
        key: String,
        fallback: String
    ) throws {
        let label = OriginalCompactRightPresentationPlan.Sessions.Label(
            key: key,
            englishFallback: fallback,
            font: sessionLabelFont,
            color: translucentWhite
        )
        let sessions = OriginalCompactRightPresentationPlan.Sessions(
            countText: countText,
            countFont: sessionCountFont,
            countColor: white,
            label: label
        )
        let localizedLabel = try appResourceBundle.localizedString(
            forKey: key,
            value: fallback,
            table: nil
        )
        let actual = try render(
            OriginalCompactRightPresentationView(plan: .sessions(sessions))
        )
        let expected = try render(
            HStack(alignment: .center, spacing: 3) {
                Text(countText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                Text(localizedLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        )

        XCTAssertNotEqual(localizedLabel, key)
        XCTAssertEqual(pngData(actual), pngData(expected))
    }

    private func render<V: View>(_ view: V) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)))
    }

    private func pngData(_ image: NSBitmapImageRep) -> Data? {
        image.representation(using: .png, properties: [:])
    }

    private var appResourceBundle: Bundle {
        get throws {
            let url = Bundle.module.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("my-vibe-island_MyVibeIslandApp.bundle", isDirectory: true)
            return try XCTUnwrap(Bundle(url: url))
        }
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalCompactRightPresentationView.swift")
    }

    private let orange = OriginalCompactRightPresentationPlan.Color(
        red: 0.98,
        green: 0.45,
        blue: 0.09,
        opacity: 1
    )
    private let orangeBackground = OriginalCompactRightPresentationPlan.Color(
        red: 0.98,
        green: 0.45,
        blue: 0.09,
        opacity: 0.2
    )
    private let green = OriginalCompactRightPresentationPlan.Color(
        red: 0.13,
        green: 0.77,
        blue: 0.37,
        opacity: 1
    )
    private let translucentGreen = OriginalCompactRightPresentationPlan.Color(
        red: 0.13,
        green: 0.77,
        blue: 0.37,
        opacity: 0.6
    )
    private let white = OriginalCompactRightPresentationPlan.Color(
        red: 1,
        green: 1,
        blue: 1,
        opacity: 1
    )
    private let translucentWhite = OriginalCompactRightPresentationPlan.Color(
        red: 1,
        green: 1,
        blue: 1,
        opacity: 0.7
    )
    private let sessionCountFont = OriginalCompactRightPresentationPlan.Font(
        size: 11,
        weight: .semibold,
        design: .monospaced
    )
    private let sessionLabelFont = OriginalCompactRightPresentationPlan.Font(
        size: 9,
        weight: .medium,
        design: .monospaced
    )
}
