import AppKit
import Combine
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalPixelStatusIconViewTests: XCTestCase {
    func testRenderingSamplesPaintBlackEyeOverlayAfterOverlappingPrimarySample() {
        let coordinate = OriginalPixelCoordinate(x: 3, y: 3)
        let blackEye = OriginalPixelSample(
            coordinate: coordinate,
            color: OriginalPixelColor(red: 0, green: 0, blue: 0)
        )
        let primary = OriginalPixelSample(
            coordinate: coordinate,
            color: OriginalPixelColor(red: 0.23, green: 0.51, blue: 0.96),
            opacity: 0.52
        )

        XCTAssertEqual(
            OriginalPixelStatusIconView.renderingSamples([blackEye, primary]),
            [primary, blackEye]
        )
    }

    func testStoredContractContainsStatusZeroPhaseAndTimerPublisher() throws {
        let view = OriginalPixelStatusIconView(status: .processing)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), ["status", "_phase", "timer"])
        XCTAssertEqual(fields["status"] as? OriginalPixelStatusCompact, .processing)
        XCTAssertEqual(try XCTUnwrap(fields["_phase"] as? State<Int>).wrappedValue, 0)
        XCTAssertNotNil(fields["timer"] as? Publishers.Autoconnect<Timer.TimerPublisher>)
    }

    func testTimerPublishesOnMainRunLoopAndPhaseWrapsModuloSeventyTwo() throws {
        let view = OriginalPixelStatusIconView(status: .processing)
        let timer = try XCTUnwrap(
            Mirror(reflecting: view).children.first { $0.label == "timer" }?.value
                as? Publishers.Autoconnect<Timer.TimerPublisher>
        )
        let receivedTick = expectation(description: "main/common timer tick")
        var cancellable: AnyCancellable?
        cancellable = timer.sink { _ in
            XCTAssertTrue(Thread.isMainThread)
            receivedTick.fulfill()
            cancellable?.cancel()
        }

        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        wait(for: [receivedTick], timeout: 0)
        XCTAssertEqual(OriginalPixelStatusIconView.nextPhase(after: 0), 1)
        XCTAssertEqual(OriginalPixelStatusIconView.nextPhase(after: 71), 0)
    }

    func testInitialPhaseRendersExactProcessingFrameSamplesIncludingOpacityAndColor() throws {
        let image = try render(OriginalPixelStatusIconView(status: .processing))
        let frame = OriginalPixelStatusCompact.frame(for: .processing, at: 0)
        let expectedByCoordinate = Dictionary(
            frame.samples.map { (key(for: $0.coordinate), $0) },
            uniquingKeysWith: { _, later in later }
        )

        XCTAssertEqual(image.pixelsWide, 32)
        XCTAssertEqual(image.pixelsHigh, 20)
        for y in 0..<OriginalPixelStatusCompact.gridHeight {
            for x in 0..<OriginalPixelStatusCompact.gridWidth {
                let expected = expectedByCoordinate["\(x),\(y)"]
                assertPixel(image, x: x, y: y, equals: expected)
            }
        }

        let partial = try XCTUnwrap(frame.samples.first { $0.opacity == 0.52 })
        assertPixel(image, coordinate: partial.coordinate, equals: partial)
        let secondary = try XCTUnwrap(frame.samples.last { $0.color == frame.secondaryColor })
        assertPixel(image, coordinate: secondary.coordinate, equals: secondary)
    }

    func testProductionSourceUsesExactCanvasTimerAndDrawingContractWithoutForbiddenMechanisms() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "@State private var phase = 0",
            "Timer.publish(",
            "every: 0.15",
            "tolerance: nil",
            "on: .main",
            "in: .common",
            "options: nil",
            ").autoconnect()",
            "Canvas(",
            "opaque: false",
            "colorMode: .nonLinear",
            "rendersAsynchronously: false",
            ".onReceive(timer)",
            "phase = Self.nextPhase(after: phase)",
            "(phase + 1) % 72",
            "OriginalPixelStatusCompact.frame(for: status, at: phase)",
            "min(size.width / 13, size.height / 8)",
            "x: (size.width - 13 * unit) / 2",
            "y: (size.height - 8 * unit) / 2",
            "CGFloat(sample.coordinate.x) * unit + 0.15",
            "CGFloat(sample.coordinate.y) * unit + 0.15",
            "width: unit - 0.3",
            "height: unit - 0.3",
            "for sample in Self.renderingSamples(frame.samples)",
            "opacity: sample.opacity",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }

        for forbidden in [
            "import AppKit",
            "NSBezierPath",
            "CALayer",
            "CADisplayLink",
            "systemName:",
            ".animation(",
            ".repeatForever(",
            ".frame(width:",
            ".frame(height:",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }
    }

    private func render(_ view: OriginalPixelStatusIconView) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 32, height: 20)
        return try XCTUnwrap(renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)))
    }

    private func assertPixel(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        equals expected: OriginalPixelSample?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let unit = min(CGFloat(image.pixelsWide) / 13, CGFloat(image.pixelsHigh) / 8)
        let offsetX = (CGFloat(image.pixelsWide) - 13 * unit) / 2
        let offsetY = (CGFloat(image.pixelsHigh) - 8 * unit) / 2
        let pixelX = Int(offsetX + (CGFloat(x) + 0.5) * unit)
        let pixelY = Int(offsetY + (CGFloat(y) + 0.5) * unit)
        let actual = image.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.sRGB)

        guard let expected else {
            XCTAssertEqual(actual?.alphaComponent ?? 0, 0, accuracy: 0.03, file: file, line: line)
            return
        }
        guard let actual else {
            return XCTFail("Missing rendered color at (\(x), \(y))", file: file, line: line)
        }
        XCTAssertEqual(actual.redComponent, expected.color.red, accuracy: 0.1, file: file, line: line)
        XCTAssertEqual(actual.greenComponent, expected.color.green, accuracy: 0.1, file: file, line: line)
        XCTAssertEqual(actual.blueComponent, expected.color.blue, accuracy: 0.1, file: file, line: line)
        XCTAssertEqual(actual.alphaComponent, expected.opacity, accuracy: 0.08, file: file, line: line)
    }

    private func assertPixel(
        _ image: NSBitmapImageRep,
        coordinate: OriginalPixelCoordinate,
        equals expected: OriginalPixelSample,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertPixel(image, x: coordinate.x, y: coordinate.y, equals: expected, file: file, line: line)
    }

    private func key(for coordinate: OriginalPixelCoordinate) -> String {
        "\(coordinate.x),\(coordinate.y)"
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalPixelStatusIconView.swift")
    }
}
