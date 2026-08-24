import XCTest
@testable import MyVibeIslandCore

final class AntigravityWatcherStateTests: XCTestCase {
    func testAntigravityWatcherStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AntigravityWatcherStateMatrixFixture.self,
            from: try FixtureLoader.data("agents/antigravity-watcher-state-matrix")
        )

        let cases = [
            AntigravityWatcherStateCase(
                name: "empty-hidden-state",
                projection: AntigravityWatcherStateProjection(AntigravityWatcherState())
            ),
            AntigravityWatcherStateCase(
                name: "hidden-state-redacts-row-identifiers-from-summary",
                projection: AntigravityWatcherStateProjection(AntigravityWatcherState(
                    watchers: [
                        AntigravityWatcherRow(
                            id: "watcher-1",
                            workspaceId: "workspace-1",
                            transcriptPath: "/tmp/antigravity/transcript.jsonl",
                            isActive: true
                        )
                    ],
                    pendingParentMap: [
                        "child-session": "parent-session"
                    ],
                    visibility: .hidden
                ))
            ),
            AntigravityWatcherStateCase(
                name: "labs-visible-state-counts-active-watchers",
                projection: AntigravityWatcherStateProjection(AntigravityWatcherState(
                    watchers: [
                        AntigravityWatcherRow(id: "watcher-b", workspaceId: "workspace-b", isActive: false),
                        AntigravityWatcherRow(id: "watcher-a", workspaceId: "workspace-a", isActive: true)
                    ],
                    pendingParentMap: [
                        "child-a": "parent-a",
                        "child-b": "parent-b"
                    ],
                    visibility: .labsOnly
                ))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testAntigravityWatcherStateSummarizesHiddenExperimentalRowsWithoutRawPaths() throws {
        let state = AntigravityWatcherState(
            watchers: [
                AntigravityWatcherRow(
                    id: "watcher-1",
                    workspaceId: "workspace-1",
                    transcriptPath: "/tmp/antigravity/transcript.jsonl",
                    isActive: true
                )
            ],
            pendingParentMap: [
                "child-session": "parent-session"
            ],
            visibility: .hidden
        )

        let summary = state.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertEqual(summary.watcherCount, 1)
        XCTAssertEqual(summary.activeWatcherCount, 1)
        XCTAssertEqual(summary.pendingParentLinkCount, 1)
        XCTAssertEqual(summary.visibility, .hidden)
        XCTAssertFalse(summary.isRuntimeVisible)

        XCTAssertFalse(encoded.contains("watcher-1"))
        XCTAssertFalse(encoded.contains("workspace-1"))
        XCTAssertFalse(encoded.contains("/tmp/antigravity"))
        XCTAssertFalse(encoded.contains("child-session"))
        XCTAssertFalse(encoded.contains("parent-session"))
    }

    private struct AntigravityWatcherStateMatrixFixture: Codable, Equatable {
        let cases: [AntigravityWatcherStateCase]
    }

    private struct AntigravityWatcherStateCase: Codable, Equatable {
        let name: String
        let projection: AntigravityWatcherStateProjection
    }

    private struct AntigravityWatcherStateProjection: Codable, Equatable {
        let watcherIds: [String]
        let summary: AntigravityWatcherDiagnosticSummary
        let encodedSummaryContainsRawIdentifiers: Bool

        init(_ state: AntigravityWatcherState) {
            self.watcherIds = state.watchers.map(\.id)
            self.summary = state.diagnosticSummary
            let encoded = (try? JSONEncoder().encode(summary))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
            self.encodedSummaryContainsRawIdentifiers = state.watchers.contains { row in
                encoded.contains(row.id)
                    || row.workspaceId.map(encoded.contains) == true
                    || row.transcriptPath.map(encoded.contains) == true
            } || state.pendingParentMap.contains { child, parent in
                encoded.contains(child) || encoded.contains(parent)
            }
        }
    }
}
