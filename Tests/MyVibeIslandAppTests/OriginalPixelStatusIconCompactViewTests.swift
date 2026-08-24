import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalPixelStatusIconCompactViewTests: XCTestCase {
    func testViewStoresOnlyStatus() {
        let view = OriginalPixelStatusIconCompactView(status: .waitingForInput)
        let storedFields = Array(Mirror(reflecting: view).children)

        XCTAssertEqual(storedFields.count, 1)
        XCTAssertEqual(storedFields.first?.label, "status")
        XCTAssertEqual(view.status, .waitingForInput)
    }

    func testCanvasRendersPaletteAndBlackEyeOverlaysAtTwentyPoints() throws {
        let status = OriginalPixelStatusCompact.waitingForApproval
        let image = try render(OriginalPixelStatusIconCompactView(status: status))
        let palette = OriginalPixelStatusPalette.colors(for: status).primary

        XCTAssertEqual(image.pixelsWide, 20)
        XCTAssertEqual(image.pixelsHigh, 20)
        assertColor(image.colorAt(x: 3, y: 8), equals: palette, accuracy: 0.1)
        assertColor(image.colorAt(x: 6, y: 8), equals: .black)
        assertColor(image.colorAt(x: 13, y: 8), equals: .black)
    }

    func testProductionSourceUsesCanvasWithoutForbiddenRenderingMechanismsOrFixedFrame() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("Canvas("))
        XCTAssertTrue(source.contains("opaque: false"))
        XCTAssertTrue(source.contains("colorMode: .nonLinear"))
        XCTAssertTrue(source.contains("rendersAsynchronously: false"))
        XCTAssertTrue(source.contains("frame.primarySamples + frame.blackSamples"))
        XCTAssertTrue(source.contains("red: sample.color.red"))
        XCTAssertTrue(source.contains("green: sample.color.green"))
        XCTAssertTrue(source.contains("blue: sample.color.blue"))
        XCTAssertTrue(source.contains("opacity: sample.opacity"))

        for forbidden in [
            "import AppKit",
            "NSView",
            "NSBezierPath",
            "CALayer",
            "Image(",
            "systemName",
            "Timer",
            "phase",
            "animation",
            ".frame(",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
    }

    private func render(_ view: OriginalPixelStatusIconCompactView) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 20, height: 20)

        return try XCTUnwrap(renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)))
    }

    private func assertColor(
        _ actual: NSColor?,
        equals expected: OriginalPixelColor,
        accuracy: CGFloat = 0.03,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color = actual?.usingColorSpace(.sRGB) else {
            return XCTFail("Missing sRGB color", file: file, line: line)
        }
        XCTAssertEqual(color.redComponent, CGFloat(expected.red), accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(color.greenComponent, CGFloat(expected.green), accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(color.blueComponent, CGFloat(expected.blue), accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(color.alphaComponent, 1, accuracy: accuracy, file: file, line: line)
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalPixelStatusIconCompactView.swift")
    }
}

private extension OriginalPixelColor {
    static let black = OriginalPixelColor(red: 0, green: 0, blue: 0)
}
