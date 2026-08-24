import XCTest
@testable import MyVibeIslandCore

final class CodexSubagentMetadataTests: XCTestCase {
    func testCodexSubagentMetadataMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexSubagentMetadataMatrixFixture.self,
            from: try FixtureLoader.data("codex/subagent-metadata-matrix")
        )

        let actual = CodexSubagentMetadataMatrixFixture(rows: [
            row(id: "full-codex-sidecar", metadata: CodexSubagentMetadata(
                codexSubagentKind: "reviewer",
                codexSubagentParentThreadId: "parent-thread",
                codexSubagentNickname: "Reviewer",
                codexSubagentRole: "review",
                source: "codex",
                rawEventId: "event-1"
            )),
            row(id: "role-label-fallback", metadata: CodexSubagentMetadata(
                codexSubagentKind: "worker",
                codexSubagentRole: "analysis"
            )),
            row(id: "kind-label-fallback", metadata: CodexSubagentMetadata(
                codexSubagentKind: "subagent"
            )),
            row(id: "empty-label-default", metadata: CodexSubagentMetadata(
                codexSubagentKind: "",
                codexSubagentNickname: "",
                codexSubagentRole: "",
                source: "",
                rawEventId: ""
            )),
            row(id: "non-codex-sidecar-source", metadata: CodexSubagentMetadata(
                codexSubagentNickname: "OpenCode helper",
                source: "opencode",
                rawEventId: "event-2"
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexSubagentMetadataRoundTripsFields() throws {
        let metadata = CodexSubagentMetadata(
            codexSubagentKind: "reviewer",
            codexSubagentParentThreadId: "parent-thread",
            codexSubagentNickname: "Reviewer",
            codexSubagentRole: "review",
            source: "codex",
            rawEventId: "event-1"
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(CodexSubagentMetadata.self, from: data)

        XCTAssertEqual(decoded, metadata)
        XCTAssertEqual(decoded.codexSubagentParentThreadId, "parent-thread")
        XCTAssertEqual(decoded.source, "codex")
        XCTAssertEqual(decoded.rawEventId, "event-1")
    }

    func testCodexSubagentMetadataDisplayLabelFallback() {
        XCTAssertEqual(
            CodexSubagentMetadata(codexSubagentNickname: "Reviewer").displayLabel,
            "Reviewer"
        )
        XCTAssertEqual(
            CodexSubagentMetadata(codexSubagentRole: "review").displayLabel,
            "review"
        )
        XCTAssertEqual(
            CodexSubagentMetadata(codexSubagentKind: "subagent").displayLabel,
            "subagent"
        )
        XCTAssertEqual(CodexSubagentMetadata().displayLabel, "Subagent")
    }

    func testCodexSubagentMetadataUsesCodexSidecarIdentity() {
        let metadata = CodexSubagentMetadata(
            codexSubagentKind: "reviewer",
            codexSubagentParentThreadId: "parent-thread",
            source: "codex",
            rawEventId: "event-1"
        )

        XCTAssertEqual(metadata.sidecarKey, "codex:event-1")
        XCTAssertTrue(metadata.isCodexSidecar)
    }

    private func row(
        id: String,
        metadata: CodexSubagentMetadata
    ) -> CodexSubagentMetadataMatrixRow {
        CodexSubagentMetadataMatrixRow(
            id: id,
            metadata: metadata,
            displayLabel: metadata.displayLabel,
            sidecarKey: metadata.sidecarKey,
            isCodexSidecar: metadata.isCodexSidecar
        )
    }

    private struct CodexSubagentMetadataMatrixFixture: Codable, Equatable {
        let rows: [CodexSubagentMetadataMatrixRow]
    }

    private struct CodexSubagentMetadataMatrixRow: Codable, Equatable {
        let id: String
        let metadata: CodexSubagentMetadata
        let displayLabel: String
        let sidecarKey: String?
        let isCodexSidecar: Bool
    }
}
