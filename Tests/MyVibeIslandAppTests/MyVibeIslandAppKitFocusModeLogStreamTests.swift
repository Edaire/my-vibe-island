import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitFocusModeLogStreamTests: XCTestCase {
    @MainActor
    func testUsesOriginalDuetExpertLogStreamCommand() {
        XCTAssertEqual(
            MyVibeIslandAppKitFocusModeLogStream.arguments,
            [
                "stream",
                "--no-backtrace",
                "--style", "compact",
                "--level", "info",
                "--predicate",
                "process == \"duetexpertd\" AND eventMessage CONTAINS \"semanticModeIdentifier\"",
            ]
        )
    }

    func testBufferEmitsCompleteLinesAcrossReadableChunks() {
        var received: [String] = []
        var buffer = FocusModeLogLineBuffer { received.append($0) }

        buffer.append(Data("semanticModeIdent".utf8))
        buffer.append(Data("ifier: com.apple.focus.work, starting: 1\nnext".utf8))
        buffer.append(Data("\n".utf8))

        XCTAssertEqual(received, [
            "semanticModeIdentifier: com.apple.focus.work, starting: 1",
            "next",
        ])
    }
}
