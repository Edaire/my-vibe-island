import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactTitleOverridesTests: XCTestCase {
    func testPhysicalNotchThinkingIgnoresDetail() {
        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .physicalNotch,
                detail: "ignored"
            ),
            .init(
                localizationKey: "tool.thinkingEllipsis",
                englishFallback: "Thinking..."
            )
        )
    }

    func testNonNotchedThinkingWithoutDetailUsesEllipsisTitle() {
        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .nonNotched,
                detail: nil
            ),
            .init(
                localizationKey: "tool.thinkingEllipsis",
                englishFallback: "Thinking..."
            )
        )
    }

    func testNonNotchedThinkingWithEmptyDetailPreservesEmptyArgument() {
        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .nonNotched,
                detail: ""
            ),
            .init(
                localizationKey: "tool.thinkingDetail",
                englishFallback: "Thinking: %@",
                formatArgument: ""
            )
        )
    }

    func testNonNotchedThinkingWith25CharactersDoesNotTruncate() {
        let detail = String(repeating: "a", count: 25)

        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .nonNotched,
                detail: detail
            )?.formatArgument,
            detail
        )
    }

    func testNonNotchedThinkingWith26CharactersTruncatesTo25AndASCIIEllipsis() {
        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .nonNotched,
                detail: String(repeating: "a", count: 26)
            )?.formatArgument,
            String(repeating: "a", count: 25) + "..."
        )
    }

    func testNonNotchedThinkingTruncatesByCharacter() {
        let character = "👩🏽‍💻"

        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(
                for: .thinking,
                mode: .nonNotched,
                detail: String(repeating: character, count: 26)
            )?.formatArgument,
            String(repeating: character, count: 25) + "..."
        )
    }

    func testCompactingUsesSameTitleInBothModes() {
        let expected = OriginalCompactTitleOverrides.Title(
            localizationKey: "status.compacting",
            englishFallback: "Compacting"
        )

        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(for: .compacting, mode: .physicalNotch),
            expected
        )
        XCTAssertEqual(
            OriginalCompactTitleOverrides.resolve(for: .compacting, mode: .nonNotched),
            expected
        )
    }

    func testUnconfirmedStatusesAreUnsupportedInBothModes() {
        let unsupported: [OriginalPixelStatusCompact] = [
            .waitingForInput,
            .processing,
            .runningTool,
            .waitingForApproval,
            .question,
            .ended,
            .unknown,
        ]

        for status in unsupported {
            XCTAssertNil(OriginalCompactTitleOverrides.resolve(for: status, mode: .physicalNotch))
            XCTAssertNil(OriginalCompactTitleOverrides.resolve(for: status, mode: .nonNotched))
        }
    }
}
