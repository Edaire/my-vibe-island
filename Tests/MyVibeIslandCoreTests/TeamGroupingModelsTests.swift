import XCTest
@testable import MyVibeIslandCore

final class TeamGroupingModelsTests: XCTestCase {
    func testTeamGroupingMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TeamGroupingMatrixFixture.self,
            from: try FixtureLoader.data("runtime/team-grouping-matrix")
        )

        let actual = TeamGroupingMatrixFixture(rows: [
            row(id: "provider-metadata-round-trip", grouping: TeamGrouping(
                groupId: "team-root",
                displayName: "Root task",
                rootSessionId: "root",
                memberSessionIds: ["child-2", "root", "child-1", "child-1"],
                source: .providerSupplied,
                confidence: 0.85,
                createdAt: "2026-07-08T18:30:00Z",
                updatedAt: "2026-07-08T18:31:00Z",
                childToParent: ["child-1": "root"],
                parentToChildren: ["root": ["child-2"]]
            )),
            row(id: "default-workspace-derived-root", grouping: TeamGrouping(
                rootSessionId: "root",
                parentToChildren: ["root": ["child"]]
            )),
            row(id: "confidence-low-clamped", grouping: TeamGrouping(
                rootSessionId: "root",
                confidence: -1.0
            )),
            row(id: "confidence-high-clamped", grouping: TeamGrouping(
                rootSessionId: "root",
                confidence: 2.0
            )),
            row(id: "parent-child-normalization", grouping: TeamGrouping(
                rootSessionId: "root",
                childToParent: ["child-2": "root"],
                parentToChildren: ["root": ["child-1", "child-1"]]
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testTeamGroupingRoundTripsDesignMetadata() throws {
        let grouping = TeamGrouping(
            groupId: "team-root",
            displayName: "Root task",
            rootSessionId: "root",
            memberSessionIds: ["child-2", "root", "child-1", "child-1"],
            source: .providerSupplied,
            confidence: 0.85,
            createdAt: "2026-07-08T18:30:00Z",
            updatedAt: "2026-07-08T18:31:00Z",
            childToParent: ["child-1": "root"],
            parentToChildren: ["root": ["child-2"]]
        )

        let data = try JSONEncoder().encode(grouping)
        let decoded = try JSONDecoder().decode(TeamGrouping.self, from: data)

        XCTAssertEqual(decoded, grouping)
        XCTAssertEqual(decoded.groupId, "team-root")
        XCTAssertEqual(decoded.displayName, "Root task")
        XCTAssertEqual(decoded.memberSessionIds, ["child-1", "child-2", "root"])
        XCTAssertEqual(decoded.source, .providerSupplied)
    }

    func testTeamGroupingDefaultsMetadataFromRootSession() {
        let grouping = TeamGrouping(rootSessionId: "root", parentToChildren: ["root": ["child"]])

        XCTAssertEqual(grouping.groupId, "root")
        XCTAssertNil(grouping.displayName)
        XCTAssertEqual(grouping.memberSessionIds, ["child", "root"])
        XCTAssertEqual(grouping.source, .workspaceDerived)
        XCTAssertEqual(grouping.confidence, 0.5)
    }

    func testTeamGroupingClampsConfidence() {
        let low = TeamGrouping(rootSessionId: "root", confidence: -1.0)
        let high = TeamGrouping(rootSessionId: "root", confidence: 2.0)

        XCTAssertEqual(low.confidence, 0.0)
        XCTAssertEqual(high.confidence, 1.0)
    }

    private func row(
        id: String,
        grouping: TeamGrouping
    ) -> TeamGroupingMatrixRow {
        TeamGroupingMatrixRow(
            id: id,
            groupId: grouping.groupId,
            displayName: grouping.displayName,
            rootSessionId: grouping.rootSessionId,
            memberSessionIds: grouping.memberSessionIds,
            source: grouping.source.rawValue,
            confidence: grouping.confidence,
            createdAt: grouping.createdAt,
            updatedAt: grouping.updatedAt,
            childToParent: grouping.childToParent,
            parentToChildren: grouping.parentToChildren
        )
    }

    private struct TeamGroupingMatrixFixture: Codable, Equatable {
        let rows: [TeamGroupingMatrixRow]
    }

    private struct TeamGroupingMatrixRow: Codable, Equatable {
        let id: String
        let groupId: String
        let displayName: String?
        let rootSessionId: String
        let memberSessionIds: [String]
        let source: String
        let confidence: Double
        let createdAt: String?
        let updatedAt: String?
        let childToParent: [String: String]
        let parentToChildren: [String: [String]]
    }
}
