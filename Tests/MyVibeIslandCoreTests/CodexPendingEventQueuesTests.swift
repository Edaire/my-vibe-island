import XCTest
@testable import MyVibeIslandCore

final class CodexPendingEventQueuesTests: XCTestCase {
    func testCodexPendingEventQueuesMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexPendingEventQueuesMatrixFixture.self,
            from: try FixtureLoader.data("codex/pending-event-queues-matrix")
        )
        let deltaTimeout = EventSchedulerTask(
            id: "debounce:codex-delta:1250",
            key: "codex-delta",
            kind: .debounce,
            dueAtMillis: 1_250,
            sourceId: "codex"
        )
        let desktopHookTimeout = EventSchedulerTask(
            id: "debounce:codex-desktop-hook:1350",
            key: "codex-desktop-hook",
            kind: .debounce,
            dueAtMillis: 1_350,
            sourceId: "codex"
        )
        let queues = CodexPendingEventQueues()
            .enqueue(
                CodexPendingEvent(id: "delta-late", sessionId: "session-2", receivedAtMillis: 1_100),
                in: .delta,
                timeout: deltaTimeout
            )
            .enqueue(
                CodexPendingEvent(id: "delta-early", sessionId: "session-1", receivedAtMillis: 1_000),
                in: .delta,
                timeout: deltaTimeout
            )
            .enqueue(
                CodexPendingEvent(id: "hook-1", sessionId: "session-3", receivedAtMillis: 1_050),
                in: .desktopHook,
                timeout: desktopHookTimeout
            )

        let actual = CodexPendingEventQueuesMatrixFixture(rows: [
            row(id: "empty", queues: CodexPendingEventQueues()),
            row(id: "separate-delta-and-desktop-hook-queues", queues: queues),
        ])

        XCTAssertEqual(actual, expected)
        let summaryPayload = String(data: try JSONEncoder().encode(queues.diagnosticSummary), encoding: .utf8) ?? ""
        XCTAssertFalse(summaryPayload.contains("delta-early"))
        XCTAssertFalse(summaryPayload.contains("hook-1"))
        XCTAssertFalse(summaryPayload.contains("session-1"))
        XCTAssertFalse(summaryPayload.contains("session-3"))
    }

    func testCodexPendingEventQueuesKeepDeltaAndDesktopHookBurstsSeparate() throws {
        let deltaTimeout = EventSchedulerTask(
            id: "debounce:codex-delta:1250",
            key: "codex-delta",
            kind: .debounce,
            dueAtMillis: 1_250,
            sourceId: "codex"
        )
        let desktopHookTimeout = EventSchedulerTask(
            id: "debounce:codex-desktop-hook:1350",
            key: "codex-desktop-hook",
            kind: .debounce,
            dueAtMillis: 1_350,
            sourceId: "codex"
        )

        let queues = CodexPendingEventQueues()
            .enqueue(
                CodexPendingEvent(id: "delta-1", sessionId: "session-1", receivedAtMillis: 1_000),
                in: .delta,
                timeout: deltaTimeout
            )
            .enqueue(
                CodexPendingEvent(id: "hook-1", sessionId: "session-2", receivedAtMillis: 1_100),
                in: .desktopHook,
                timeout: desktopHookTimeout
            )

        XCTAssertEqual(queues.pendingCodexDeltas.map(\.id), ["delta-1"])
        XCTAssertEqual(queues.pendingCodexDeltaTimeout, deltaTimeout)
        XCTAssertEqual(queues.pendingCodexDesktopHooks.map(\.id), ["hook-1"])
        XCTAssertEqual(queues.pendingCodexDesktopHookTimeout, desktopHookTimeout)

        let summary = queues.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertEqual(summary.pendingDeltaCount, 1)
        XCTAssertEqual(summary.pendingDesktopHookCount, 1)
        XCTAssertTrue(summary.hasDeltaTimeout)
        XCTAssertTrue(summary.hasDesktopHookTimeout)
        XCTAssertEqual(summary.pendingTotalCount, 2)
        XCTAssertFalse(encoded.contains("delta-1"))
        XCTAssertFalse(encoded.contains("hook-1"))
        XCTAssertFalse(encoded.contains("session-1"))
        XCTAssertFalse(encoded.contains("session-2"))
    }

    private func row(
        id: String,
        queues: CodexPendingEventQueues
    ) -> CodexPendingEventQueuesMatrixRow {
        CodexPendingEventQueuesMatrixRow(
            id: id,
            queues: queues,
            diagnosticSummary: queues.diagnosticSummary
        )
    }

    private struct CodexPendingEventQueuesMatrixFixture: Codable, Equatable {
        let rows: [CodexPendingEventQueuesMatrixRow]
    }

    private struct CodexPendingEventQueuesMatrixRow: Codable, Equatable {
        let id: String
        let queues: CodexPendingEventQueues
        let diagnosticSummary: CodexPendingEventQueueSummary
    }
}
