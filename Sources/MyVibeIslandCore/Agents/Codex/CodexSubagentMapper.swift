public struct CodexSubagentMapper: Sendable {
    public init() {}

    public func subagentState(
        parentSessionId: String,
        thread: CodexSubagentThread,
        metadata: CodexSubagentMetadata? = nil,
        source: CodexSubagentSource? = nil
    ) -> SubagentState {
        SubagentState(
            id: thread.identityKey,
            source: metadata?.source ?? source?.sourceId ?? "codex",
            parentSessionId: parentSessionId,
            parentThreadId: thread.parentThreadId ?? metadata?.codexSubagentParentThreadId ?? source?.parentThreadId,
            threadId: thread.childThreadId,
            kind: metadata?.codexSubagentKind ?? source?.subagentKind ?? thread.spawnKind,
            nickname: metadata?.codexSubagentNickname ?? thread.agentNickname,
            role: metadata?.codexSubagentRole ?? thread.agentRole,
            status: nil,
            sourceDetailId: source?.subagentDetailId
        )
    }

    public func hierarchyNode(
        parentSessionId: String,
        thread: CodexSubagentThread,
        metadata: CodexSubagentMetadata? = nil,
        source: CodexSubagentSource? = nil
    ) -> CodexThreadHierarchyNode {
        let state = subagentState(
            parentSessionId: parentSessionId,
            thread: thread,
            metadata: metadata,
            source: source
        )

        return CodexThreadHierarchyNode(
            id: state.id,
            parentThreadId: state.parentThreadId,
            threadId: state.threadId,
            kind: state.kind,
            firstSeenAt: thread.observedAt ?? source?.observedAt ?? "",
            lastSeenAt: thread.observedAt ?? source?.observedAt
        ).markingDetachedIfNeeded()
    }
}
