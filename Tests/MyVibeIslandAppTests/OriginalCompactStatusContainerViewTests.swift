import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalCompactStatusContainerViewTests: XCTestCase {
    func testViewStoresOnlyEvidenceRequiredInputs() {
        let view = OriginalCompactStatusContainerView(
            status: .runningTool,
            isMinimized: true,
            completionFlashProgress: 0.4
        )
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), ["status", "isMinimized", "completionFlashProgress"])
        XCTAssertEqual(fields["status"] as? OriginalPixelStatusCompact, .runningTool)
        XCTAssertEqual(fields["isMinimized"] as? Bool, true)
        XCTAssertEqual(fields["completionFlashProgress"] as? Double, 0.4)
    }

    func testSemanticGlowColorMapping() throws {
        let expected: [(OriginalPixelStatusCompact, Color)] = [
            (.waitingForInput, .green),
            (.processing, .blue),
            (.runningTool, .blue),
            (.thinking, .purple),
            (.compacting, .purple),
            (.waitingForApproval, .orange),
            (.question, .orange),
            (.ended, .gray),
            (.unknown, .gray),
        ]

        for (status, expectedColor) in expected {
            let actual = try XCTUnwrap(
                NSColor(OriginalCompactStatusContainerView.glowColor(for: status))
                    .usingColorSpace(.sRGB)
            )
            let expected = try XCTUnwrap(NSColor(expectedColor).usingColorSpace(.sRGB))
            XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.001)
            XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.001)
            XCTAssertEqual(actual.blueComponent, expected.blueComponent, accuracy: 0.001)
            XCTAssertEqual(actual.alphaComponent, 1, accuracy: 0.001)
        }
    }

    func testMinimizedBranchRendersTwentyByTwentyFromLargerProposal() throws {
        let image = try render(
            OriginalCompactStatusContainerView(
                status: .waitingForInput,
                isMinimized: true,
                completionFlashProgress: 0
            ),
            proposedSize: ProposedViewSize(width: 200, height: 120)
        )

        XCTAssertEqual(image.pixelsWide, 20)
        XCTAssertEqual(image.pixelsHigh, 20)
    }

    func testNonMinimizedBranchRendersThirtyTwoByTwentyFromLargerProposal() throws {
        let image = try render(
            OriginalCompactStatusContainerView(
                status: .waitingForInput,
                isMinimized: false,
                completionFlashProgress: 0
            ),
            proposedSize: ProposedViewSize(width: 200, height: 120)
        )

        XCTAssertEqual(image.pixelsWide, 32)
        XCTAssertEqual(image.pixelsHigh, 20)
    }

    func testProductionSourceLocksBranchTypesFramesAndExactModifierOrder() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let requiredInOrder = [
            "if isMinimized {",
            "OriginalPixelStatusIconCompactView(status: status)",
            ".frame(width: 20, height: 20)",
            ".shadow(color: glowColor.opacity(0.5), radius: 2, x: 0, y: 0)",
            ".shadow(color: glowColor.opacity(0.25), radius: 6, x: 0, y: 0)",
            "OriginalPixelStatusIconView(status: status)",
            ".frame(width: 32, height: 20)",
            ".shadow(color: glowColor.opacity(0.5), radius: 3, x: 0, y: 0)",
            ".shadow(color: glowColor.opacity(0.2), radius: 8, x: 0, y: 0)",
            ".shadow(color: Self.completionGlowColor.opacity(completionFlashProgress), radius: 7, x: 0, y: 0)",
            ".shadow(color: Self.completionGlowColor.opacity(0.6 * completionFlashProgress), radius: 13, x: 0, y: 0)",
            ".scaleEffect(CGFloat(1 + 0.18 * completionFlashProgress), anchor: .center)",
        ]

        var searchStart = source.startIndex
        for required in requiredInOrder {
            let range = try XCTUnwrap(source.range(of: required, range: searchStart..<source.endIndex))
            searchStart = range.upperBound
        }
    }

    func testProductionSourceUsesSemanticGlowColorsAndNoForbiddenMechanisms() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "Color(red: 0.13, green: 0.77, blue: 0.37)",
            "case .waitingForInput:\n            .green",
            "case .processing, .runningTool:\n            .blue",
            "case .thinking, .compacting:\n            .purple",
            "case .waitingForApproval, .question:\n            .orange",
            "case .ended, .unknown:\n            .gray",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }

        let glowColorFunction = try XCTUnwrap(source.range(of: "static func glowColor(for status:"))
        XCTAssertFalse(
            source[glowColorFunction.lowerBound...].contains("Color(red:"),
            "glowColor(for:) must use SwiftUI semantic colors"
        )

        for forbidden in [
            "import AppKit",
            "Timer",
            "CALayer",
            "NSView",
            "NSBezierPath",
            "Image(",
            "systemName",
            "GeometryReader",
            ".animation(",
            "withAnimation",
            "clamp",
            "min(completionFlashProgress",
            "max(completionFlashProgress",
            ".padding(",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
        XCTAssertEqual(source.components(separatedBy: ".frame(").count - 1, 2)
    }

    private func render(
        _ view: OriginalCompactStatusContainerView,
        proposedSize: ProposedViewSize
    ) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = proposedSize
        return try XCTUnwrap(renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)))
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalCompactStatusContainerView.swift")
    }
}
