import XCTest
@testable import MyVibeIslandCore

final class CodexWriterInfoTests: XCTestCase {
    func testCodexWriterInfoMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexWriterInfoMatrixFixture.self,
            from: try FixtureLoader.data("agents/codex-writer-info-matrix")
        )

        let actual = CodexWriterInfoMatrixFixture(rows: [
            CodexWriterInfoMatrixRow(
                id: "matched-full-identity",
                info: CodexWriterInfo(
                    tty: "/dev/ttys001",
                    pid: 4242,
                    terminalBundleId: "com.googlecode.iterm2",
                    outcome: .matched
                )
            ),
            CodexWriterInfoMatrixRow(
                id: "admission-denied-outcome",
                info: CodexWriterInfo(
                    admissionDeniedAncestorBundleId: "com.example.denied",
                    outcome: .admissionDenied
                )
            ),
            CodexWriterInfoMatrixRow(
                id: "admission-denied-ancestor-only",
                info: CodexWriterInfo(
                    admissionDeniedAncestorBundleId: "com.example.denied",
                    outcome: .unknown
                )
            ),
            CodexWriterInfoMatrixRow(
                id: "not-found-no-identity",
                info: CodexWriterInfo(outcome: .notFound)
            ),
            CodexWriterInfoMatrixRow(
                id: "partial-terminal-identity",
                info: CodexWriterInfo(
                    tty: "/dev/ttys002",
                    terminalBundleId: "com.apple.Terminal",
                    outcome: .matched
                )
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexWriterInfoRoundTripsObservedFields() throws {
        let info = CodexWriterInfo(
            tty: "/dev/ttys001",
            pid: 4242,
            terminalBundleId: "com.googlecode.iterm2",
            admissionDeniedAncestorBundleId: "com.example.denied",
            outcome: .admissionDenied
        )

        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(CodexWriterInfo.self, from: data)

        XCTAssertEqual(decoded, info)
        XCTAssertEqual(decoded.tty, "/dev/ttys001")
        XCTAssertEqual(decoded.pid, 4242)
        XCTAssertEqual(decoded.terminalBundleId, "com.googlecode.iterm2")
        XCTAssertEqual(decoded.admissionDeniedAncestorBundleId, "com.example.denied")
    }

    func testCodexWriterOutcomeDecodesDocumentationNames() throws {
        let decoded = try JSONDecoder().decode(CodexWriterOutcome.self, from: Data(#""matched""#.utf8))

        XCTAssertEqual(decoded, .matched)
    }

    func testCodexWriterInfoAdmissionDeniedDerivation() {
        let denied = CodexWriterInfo(
            admissionDeniedAncestorBundleId: "com.example.denied",
            outcome: .admissionDenied
        )
        let matched = CodexWriterInfo(outcome: .matched)

        XCTAssertTrue(denied.isAdmissionDenied)
        XCTAssertFalse(matched.isAdmissionDenied)
    }

    func testCodexWriterInfoBuildsTerminalIdentityKey() {
        let info = CodexWriterInfo(
            tty: "/dev/ttys001",
            pid: 4242,
            terminalBundleId: "com.googlecode.iterm2",
            outcome: .matched
        )

        XCTAssertEqual(
            info.terminalIdentityKey,
            "pid=4242|terminalBundleId=com.googlecode.iterm2|tty=/dev/ttys001"
        )
    }
}

private struct CodexWriterInfoMatrixFixture: Codable, Equatable {
    let rows: [CodexWriterInfoMatrixRow]
}

private struct CodexWriterInfoMatrixRow: Codable, Equatable {
    let id: String
    let tty: String?
    let pid: Int?
    let terminalBundleId: String?
    let admissionDeniedAncestorBundleId: String?
    let outcome: CodexWriterOutcome
    let isAdmissionDenied: Bool
    let terminalIdentityKey: String?

    init(id: String, info: CodexWriterInfo) {
        self.id = id
        tty = info.tty
        pid = info.pid
        terminalBundleId = info.terminalBundleId
        admissionDeniedAncestorBundleId = info.admissionDeniedAncestorBundleId
        outcome = info.outcome
        isAdmissionDenied = info.isAdmissionDenied
        terminalIdentityKey = info.terminalIdentityKey
    }
}
