import XCTest
@testable import MyVibeIslandCore

final class CodexThreadHierarchyTests: XCTestCase {
    func testCodexThreadHierarchyMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexThreadHierarchyMatrixFixture.self,
            from: try FixtureLoader.data("codex/thread-hierarchy-matrix")
        )

        let actual = CodexThreadHierarchyMatrixFixture(rows: [
            row(id: "normalized-children-and-state-sets", hierarchy: CodexThreadHierarchy(
                rootSessionId: "session-1",
                rootThreadId: "root-thread",
                childNodes: [
                    CodexThreadHierarchyNode(
                        id: "late",
                        parentThreadId: "root-thread",
                        threadId: "thread-late",
                        kind: "reviewer",
                        firstSeenAt: "2026-07-08T20:02:00Z"
                    ),
                    CodexThreadHierarchyNode(
                        id: "early",
                        parentThreadId: "root-thread",
                        threadId: "thread-early",
                        kind: "coder",
                        firstSeenAt: "2026-07-08T20:01:00Z"
                    ),
                    CodexThreadHierarchyNode(
                        id: "late",
                        parentThreadId: "root-thread",
                        kind: "reviewer-updated",
                        firstSeenAt: "2026-07-08T20:03:00Z",
                        lastSeenAt: "2026-07-08T20:04:00Z"
                    )
                ],
                activeChildId: "late",
                completedChildIds: ["done-2", "done-1", "done-1"],
                failedChildIds: ["failed-2", "failed-1", "failed-2"]
            )),
            row(id: "detached-child", hierarchy: CodexThreadHierarchy(
                rootSessionId: "session-2",
                rootThreadId: "root-thread",
                childNodes: [
                    CodexThreadHierarchyNode(
                        id: "detached",
                        threadId: "thread-detached",
                        kind: "reviewer",
                        firstSeenAt: "2026-07-08T20:05:00Z"
                    )
                ],
                detachedChildIds: ["manual-detached"]
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexThreadHierarchyRoundTripsFields() throws {
        let hierarchy = CodexThreadHierarchy(
            rootSessionId: "session-1",
            rootThreadId: "root-thread",
            childNodes: [
                CodexThreadHierarchyNode(
                    id: "child-1",
                    parentThreadId: "root-thread",
                    threadId: "thread-1",
                    kind: "reviewer",
                    firstSeenAt: "2026-07-08T20:00:00Z",
                    lastSeenAt: "2026-07-08T20:10:00Z"
                )
            ],
            activeChildId: "child-1",
            completedChildIds: ["child-2"],
            failedChildIds: ["child-3"],
            detachedChildIds: ["child-4"]
        )

        let data = try JSONEncoder().encode(hierarchy)
        let decoded = try JSONDecoder().decode(CodexThreadHierarchy.self, from: data)

        XCTAssertEqual(decoded, hierarchy)
        XCTAssertEqual(decoded.rootSessionId, "session-1")
        XCTAssertEqual(decoded.activeChildId, "child-1")
    }

    func testCodexThreadHierarchyOrdersChildrenByFirstSeenAt() {
        let hierarchy = CodexThreadHierarchy(
            rootSessionId: "session-1",
            rootThreadId: "root-thread",
            childNodes: [
                CodexThreadHierarchyNode(id: "late", parentThreadId: "root-thread", firstSeenAt: "2026-07-08T20:02:00Z"),
                CodexThreadHierarchyNode(id: "early", parentThreadId: "root-thread", firstSeenAt: "2026-07-08T20:01:00Z")
            ]
        )

        XCTAssertEqual(hierarchy.childNodes.map(\.id), ["early", "late"])
    }

    func testCodexThreadHierarchyUpdatesDuplicateChildById() {
        let hierarchy = CodexThreadHierarchy(
            rootSessionId: "session-1",
            rootThreadId: "root-thread",
            childNodes: [
                CodexThreadHierarchyNode(id: "child", parentThreadId: "root-thread", kind: "reviewer", firstSeenAt: "2026-07-08T20:01:00Z"),
                CodexThreadHierarchyNode(id: "child", parentThreadId: "root-thread", kind: "coder", firstSeenAt: "2026-07-08T20:02:00Z")
            ]
        )

        XCTAssertEqual(hierarchy.childNodes.count, 1)
        XCTAssertEqual(hierarchy.childNodes.first?.kind, "coder")
        XCTAssertEqual(hierarchy.childNodes.first?.firstSeenAt, "2026-07-08T20:01:00Z")
    }

    func testCodexThreadHierarchyMarksMissingParentAsDetached() {
        let hierarchy = CodexThreadHierarchy(
            rootSessionId: "session-1",
            rootThreadId: "root-thread",
            childNodes: [
                CodexThreadHierarchyNode(id: "detached", threadId: "thread-1", firstSeenAt: "2026-07-08T20:01:00Z")
            ]
        )

        XCTAssertEqual(hierarchy.detachedChildIds, ["detached"])
        XCTAssertEqual(hierarchy.childNodes.first?.diagnosticReason, "missingParentThreadId")
    }

    private func row(
        id: String,
        hierarchy: CodexThreadHierarchy
    ) -> CodexThreadHierarchyMatrixRow {
        CodexThreadHierarchyMatrixRow(id: id, hierarchy: hierarchy)
    }

    private struct CodexThreadHierarchyMatrixFixture: Codable, Equatable {
        let rows: [CodexThreadHierarchyMatrixRow]
    }

    private struct CodexThreadHierarchyMatrixRow: Codable, Equatable {
        let id: String
        let hierarchy: CodexThreadHierarchy
    }
}
