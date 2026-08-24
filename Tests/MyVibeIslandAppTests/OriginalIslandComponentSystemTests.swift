import XCTest
@testable import MyVibeIslandApp

final class OriginalIslandComponentSystemTests: XCTestCase {
    func testRecoveredComponentTokensKeepSharedCardAndPillGeometry() {
        let tokens = OriginalIslandComponentTokens.original

        XCTAssertEqual(tokens.cardCornerRadius, 10)
        XCTAssertEqual(tokens.cardHorizontalInset, 8)
        XCTAssertEqual(tokens.cardVerticalInset, 8)
        XCTAssertEqual(tokens.pillHorizontalInset, 5)
        XCTAssertEqual(tokens.pillVerticalInset, 2)
        XCTAssertEqual(tokens.pillFontSize, 9)
        XCTAssertEqual(tokens.completionHeaderOpacity, 0.10)
        XCTAssertEqual(tokens.completionViewportOpacity, 0.08)
    }

    func testComponentSystemExposesOriginalCardPillAndCompletionRoles() throws {
        let source = try String(contentsOf: componentSourceURL, encoding: .utf8)

        for required in [
            "struct OriginalCardContainerView",
            "struct OriginalTagPill",
            "struct OriginalJumpToTerminalPill",
            "struct OriginalCompletionCardView",
        ] {
            XCTAssertTrue(source.contains(required), "Missing recovered component: \(required)")
        }
    }

    func testProviderPillPaletteUsesObservedCodexAndClaudeAccents() {
        XCTAssertEqual(OriginalTagPillPalette.resolve("codex"), .codex)
        XCTAssertEqual(OriginalTagPillPalette.resolve("Claude"), .claude)
        XCTAssertEqual(OriginalTagPillPalette.resolve("hermes"), .neutral)
    }

    private var componentSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalIslandComponentSystem.swift")
    }
}
