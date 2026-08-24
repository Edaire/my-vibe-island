import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedHeaderControlsViewTests: XCTestCase {
    func testActionsForwardToSoundAndSettingsHandlers() {
        var actions: [OriginalExpandedHeaderControlAction] = []
        let view = OriginalExpandedHeaderControlsView(
            soundEnabled: true,
            onToggleSound: { actions.append(.toggleSound) },
            onOpenSettings: { actions.append(.openSettings) }
        )

        view.perform(.toggleSound)
        view.perform(.openSettings)

        XCTAssertEqual(actions, [.toggleSound, .openSettings])
    }

    func testProductionSourceUsesPlainFixedSpeakerAndSettingsControls() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "OriginalExpandedSessionLayoutPlan.original",
            "speaker.wave.2.fill",
            "speaker.slash.fill",
            "gearshape.fill",
            ".font(.system(size: CGFloat(layout.controlGlyph), weight: .medium))",
            ".frame(width: CGFloat(layout.controlFrame), height: CGFloat(layout.controlFrame))",
            "HStack(spacing: CGFloat(layout.controlSpacing))",
            ".help(\"Toggle sounds\")",
            ".help(\"Open Settings\")",
        ] {
            XCTAssertTrue(source.contains(required), "Missing header control source: \(required)")
        }

        for required in [
            ".font(.system(size: CGFloat(layout.controlGlyph), weight: .medium))",
            ".frame(width: CGFloat(layout.controlFrame), height: CGFloat(layout.controlFrame))",
            ".buttonStyle(.plain)",
        ] {
            XCTAssertEqual(occurrenceCount(of: required, in: source), 2, "Expected both header controls to use: \(required)")
        }
    }

    func testReservedWidthMatchesTwoControlsAndTheirSpacing() {
        XCTAssertEqual(OriginalExpandedHeaderControlsView.reservedWidth, 56)
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalExpandedHeaderControlsView.swift")
    }

    private func occurrenceCount(of needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }
}
