import XCTest
@testable import MyVibeIslandCore

final class CodexSubagentMapperTests: XCTestCase {
    func testThreadSpawnRetainsNoSpawnShapeWithoutDirectCodexEvidence() {
        let state = CodexSubagentMapper().subagentState(
            parentSessionId: "parent",
            thread: CodexSubagentThread(
                parentThreadId: "parent-thread",
                agentNickname: "researcher",
                agentRole: "research",
                childThreadId: "child-thread",
                spawnKind: "thread_spawn",
                observedAt: "2026-08-19T09:00:00Z"
            )
        )

        XCTAssertNil(state.spawnShape)
        XCTAssertNil(state.teammateIdentity)
    }

    func testSubagentStatePreservesExplicitV3SpawnMetadata() {
        let state = SubagentState(
            id: "child",
            source: "claude",
            parentSessionId: "parent",
            parentThreadId: nil,
            threadId: nil,
            kind: nil,
            nickname: nil,
            role: nil,
            status: "running",
            sourceDetailId: nil,
            startedAt: nil,
            completedAt: nil,
            hasLifecycleSignal: true,
            currentActivity: nil,
            needsAttention: false,
            spawnShape: .teammate(inProcess: true),
            teammateIdentity: "worker-1"
        )

        XCTAssertEqual(state.spawnShape, .teammate(inProcess: true))
        XCTAssertEqual(state.teammateIdentity, "worker-1")
    }
    func testCodexSubagentMapperMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexSubagentMapperMatrixFixture.self,
            from: try FixtureLoader.data("codex/subagent-mapper-matrix")
        )
        let mapper = CodexSubagentMapper()

        let metadata = CodexSubagentMetadata(
            codexSubagentKind: "reviewer",
            codexSubagentParentThreadId: "metadata-parent-thread",
            codexSubagentNickname: "Metadata Reviewer",
            codexSubagentRole: "metadata-review",
            source: "codex",
            rawEventId: "event-1"
        )
        let source = CodexSubagentSource(
            sourceId: "codex",
            subagentKind: "source-reviewer",
            parentThreadId: "source-parent-thread",
            subagentDetailId: "detail-1",
            rawEventId: "event-1",
            observedAt: "2026-07-08T20:40:00Z"
        )

        let actual = CodexSubagentMapperMatrixFixture(rows: [
            CodexSubagentMapperMatrixRow(
                id: "child-thread-with-metadata",
                state: mapper.subagentState(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(
                        parentThreadId: "thread-parent",
                        agentNickname: "Thread Reviewer",
                        agentRole: "thread-review",
                        childThreadId: "child-thread",
                        spawnKind: "subagent",
                        observedAt: "2026-07-08T20:35:00Z"
                    ),
                    metadata: metadata,
                    source: source
                ),
                node: mapper.hierarchyNode(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(
                        parentThreadId: "thread-parent",
                        agentNickname: "Thread Reviewer",
                        agentRole: "thread-review",
                        childThreadId: "child-thread",
                        spawnKind: "subagent",
                        observedAt: "2026-07-08T20:35:00Z"
                    ),
                    metadata: metadata,
                    source: source
                )
            ),
            CodexSubagentMapperMatrixRow(
                id: "source-detail-without-metadata",
                state: mapper.subagentState(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(parentThreadId: "thread-parent", childThreadId: "child-from-source"),
                    source: source
                ),
                node: mapper.hierarchyNode(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(parentThreadId: "thread-parent", childThreadId: "child-from-source"),
                    source: source
                )
            ),
            CodexSubagentMapperMatrixRow(
                id: "weak-fallback-detached",
                state: mapper.subagentState(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(
                        agentNickname: "Detached",
                        agentRole: "research",
                        spawnKind: "subagent",
                        observedAt: "2026-07-08T20:45:00Z"
                    )
                ),
                node: mapper.hierarchyNode(
                    parentSessionId: "session-1",
                    thread: CodexSubagentThread(
                        agentNickname: "Detached",
                        agentRole: "research",
                        spawnKind: "subagent",
                        observedAt: "2026-07-08T20:45:00Z"
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexSubagentMapperPrefersChildThreadIdForSubagentIdentity() {
        let mapper = CodexSubagentMapper()
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review",
            childThreadId: "child-thread",
            spawnKind: "subagent"
        )
        let metadata = CodexSubagentMetadata(
            codexSubagentKind: "reviewer",
            codexSubagentParentThreadId: "parent-thread",
            codexSubagentNickname: "Reviewer",
            codexSubagentRole: "review",
            source: "codex",
            rawEventId: "event-1"
        )

        let state = mapper.subagentState(
            parentSessionId: "session-1",
            thread: thread,
            metadata: metadata
        )

        XCTAssertEqual(state.id, "child-thread")
        XCTAssertEqual(state.source, "codex")
        XCTAssertEqual(state.parentSessionId, "session-1")
        XCTAssertEqual(state.parentThreadId, "parent-thread")
        XCTAssertEqual(state.threadId, "child-thread")
        XCTAssertEqual(state.kind, "reviewer")
        XCTAssertEqual(state.nickname, "Reviewer")
        XCTAssertEqual(state.role, "review")
    }

    func testCodexSubagentMapperUsesWeakFallbackIdentityWithoutChildThreadId() {
        let mapper = CodexSubagentMapper()
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review",
            spawnKind: "subagent"
        )

        let state = mapper.subagentState(parentSessionId: "session-1", thread: thread)

        XCTAssertEqual(
            state.id,
            "weak:agentNickname=Reviewer|agentRole=review|parentThreadId=parent-thread|spawnKind=subagent"
        )
        XCTAssertNil(state.threadId)
    }

    func testCodexSubagentMapperPropagatesSourceDetailId() {
        let mapper = CodexSubagentMapper()
        let thread = CodexSubagentThread(parentThreadId: "parent-thread", childThreadId: "child-thread")
        let source = CodexSubagentSource(
            sourceId: "codex",
            subagentKind: "reviewer",
            parentThreadId: "parent-thread",
            subagentDetailId: "detail-1",
            rawEventId: "event-1"
        )

        let state = mapper.subagentState(
            parentSessionId: "session-1",
            thread: thread,
            source: source
        )

        XCTAssertEqual(state.sourceDetailId, "detail-1")
        XCTAssertEqual(state.kind, "reviewer")
    }

    func testCodexSubagentMapperBuildsHierarchyNodeFromMappedState() {
        let mapper = CodexSubagentMapper()
        let thread = CodexSubagentThread(
            agentNickname: "Reviewer",
            childThreadId: "child-thread",
            observedAt: "2026-07-08T20:45:00Z"
        )

        let node = mapper.hierarchyNode(parentSessionId: "session-1", thread: thread)

        XCTAssertEqual(node.id, "child-thread")
        XCTAssertNil(node.parentThreadId)
        XCTAssertEqual(node.threadId, "child-thread")
        XCTAssertEqual(node.firstSeenAt, "2026-07-08T20:45:00Z")
        XCTAssertEqual(node.diagnosticReason, "missingParentThreadId")
    }
}

private struct CodexSubagentMapperMatrixFixture: Codable, Equatable {
    let rows: [CodexSubagentMapperMatrixRow]
}

private struct CodexSubagentMapperMatrixRow: Codable, Equatable {
    let id: String
    let state: SubagentState
    let hierarchyNode: CodexThreadHierarchyNode

    init(id: String, state: SubagentState, node: CodexThreadHierarchyNode) {
        self.id = id
        self.state = state
        self.hierarchyNode = node
    }
}
