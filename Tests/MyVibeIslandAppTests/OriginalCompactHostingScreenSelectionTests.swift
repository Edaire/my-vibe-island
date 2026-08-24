import XCTest
@testable import MyVibeIslandApp

final class OriginalCompactHostingScreenSelectionTests: XCTestCase {
    func testSelectedIdentifierMatchWins() {
        let selected = input(32)

        let result = OriginalCompactHostingScreenSelection.resolve(
            candidates: [
                OriginalCompactHostingScreenCandidate(identifier: "main", input: input(24)),
                OriginalCompactHostingScreenCandidate(identifier: "selected", input: selected),
            ],
            selectedIdentifier: "selected",
            mainIdentifier: "main",
            fallback: input(0)
        )

        XCTAssertEqual(result, selected)
    }

    func testMissingSelectedIdentifierFallsBackToMainIdentifierMatch() {
        let main = input(28)

        let result = OriginalCompactHostingScreenSelection.resolve(
            candidates: [
                OriginalCompactHostingScreenCandidate(identifier: "first", input: input(20)),
                OriginalCompactHostingScreenCandidate(identifier: "main", input: main),
            ],
            selectedIdentifier: "missing",
            mainIdentifier: "main",
            fallback: input(0)
        )

        XCTAssertEqual(result, main)
    }

    func testMissingSelectedAndMainIdentifiersFallBackToFirstCandidate() {
        let first = input(20)

        let result = OriginalCompactHostingScreenSelection.resolve(
            candidates: [
                OriginalCompactHostingScreenCandidate(identifier: "first", input: first),
                OriginalCompactHostingScreenCandidate(identifier: "second", input: input(18)),
            ],
            selectedIdentifier: "missing-selected",
            mainIdentifier: "missing-main",
            fallback: input(0)
        )

        XCTAssertEqual(result, first)
    }

    func testEmptyCandidatesUseExplicitFallbackInput() {
        let fallback = input(16)

        let result = OriginalCompactHostingScreenSelection.resolve(
            candidates: [],
            selectedIdentifier: "missing-selected",
            mainIdentifier: "missing-main",
            fallback: fallback
        )

        XCTAssertEqual(result, fallback)
    }
}

private func input(_ safeAreaTopInset: Double) -> OriginalNSScreenMetricsInput {
    OriginalNSScreenMetricsInput(
        safeAreaTopInset: safeAreaTopInset,
        frameWidth: 1512,
        auxiliaryTopLeftWidth: 663,
        auxiliaryTopRightWidth: 664
    )
}
