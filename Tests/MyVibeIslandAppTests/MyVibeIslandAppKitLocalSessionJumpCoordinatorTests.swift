import Dispatch
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitLocalSessionJumpCoordinatorTests: XCTestCase {
    @MainActor
    func testSelectSessionPersistsActiveSessionThroughRuntime() {
        let store = InMemorySessionStore()
        let runtime = AppRuntime(sessionStore: store)
        let coordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(runtime: runtime)

        coordinator.selectSession("session-1")

        XCTAssertEqual(runtime.sessionStoreIndexes().activeSessionId, "session-1")
        XCTAssertEqual(coordinator.lastSelectedSessionId, "session-1")
    }

    @MainActor
    func testJumpSessionRunsOffMainActorAndPublishesResultAfterCompletion() async throws {
        let executor = BlockingJumpExecutor()
        let coordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(
            runtime: AppRuntime(),
            executeJump: executor.execute
        )

        XCTAssertTrue(coordinator.jumpToSession("session-1"))
        XCTAssertEqual(coordinator.lastJumpedSessionId, "session-1")
        XCTAssertTrue(coordinator.isJumpInFlight("session-1"))
        XCTAssertNil(coordinator.lastJumpResult)
        XCTAssertEqual(executor.waitForStarts(count: 1), .success)

        executor.releaseAll()
        try await waitUntil { !coordinator.isJumpInFlight("session-1") }

        XCTAssertEqual(coordinator.lastJumpResult?.status, .executed)
    }

    @MainActor
    func testJumpSessionCoalescesDuplicatesButAllowsDifferentSessions() async throws {
        let executor = BlockingJumpExecutor()
        let coordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(
            runtime: AppRuntime(),
            executeJump: executor.execute
        )

        XCTAssertTrue(coordinator.jumpToSession("session-1"))
        XCTAssertFalse(coordinator.jumpToSession("session-1"))
        XCTAssertTrue(coordinator.jumpToSession("session-2"))
        XCTAssertEqual(executor.waitForStarts(count: 2), .success)

        executor.releaseAll()
        try await waitUntil {
            !coordinator.isJumpInFlight("session-1")
                && !coordinator.isJumpInFlight("session-2")
        }

        XCTAssertTrue(coordinator.jumpToSession("session-1"))
        XCTAssertEqual(executor.waitForStarts(count: 1), .success)
        executor.releaseAll()
    }

    @MainActor
    func testActionResolutionDelegatesToRuntime() {
        let runtime = AppRuntime()
        let coordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(runtime: runtime)
        let resolution = ActionResolution(
            requestId: "request-1",
            sessionId: "session-1",
            kind: .deny
        )

        XCTAssertFalse(coordinator.resolveAction(resolution))
    }

    @MainActor
    func testLegacyRoutesBecomeTypedResolutionsAndUnknownRequestsFailClosed() {
        let request = ActionableRequest(
            requestId: "request-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "terminal"
        )
        let runtime = AppRuntime(sessionCoordinator: SessionCoordinator(sessions: [
            SessionState(
                sessionId: "session-1",
                source: "codex",
                cwd: "/tmp",
                pendingRequestIds: ["request-1"],
                actionableRequests: [request]
            )
        ]))
        let coordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(runtime: runtime)

        XCTAssertTrue(coordinator.resolveAction(requestId: "request-1", sessionId: "session-1"))
        XCTAssertEqual(coordinator.lastLegacyResolution?.kind, .approve)
        XCTAssertFalse(coordinator.resolveAnswer(requestId: "missing", sessionId: "missing"))
        XCTAssertEqual(coordinator.lastLegacyResolution?.kind, .answer)
        XCTAssertEqual(runtime.actionableRequests().count, 0)
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @MainActor @escaping () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else {
            XCTFail("Timed out waiting for asynchronous jump completion")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private final class BlockingJumpExecutor: @unchecked Sendable {
    private let started = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var startCount = 0

    func execute(sessionID: String) -> TerminalJumpExecutionResult {
        lock.lock()
        startCount += 1
        lock.unlock()
        started.signal()
        release.wait()
        return TerminalJumpExecutionResult(
            sessionId: sessionID,
            status: .executed,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "executed"
        )
    }

    func waitForStarts(count: Int) -> DispatchTimeoutResult {
        for _ in 0..<count {
            guard started.wait(timeout: .now() + 1) == .success else { return .timedOut }
        }
        return .success
    }

    func releaseAll() {
        lock.lock()
        let count = startCount
        lock.unlock()
        for _ in 0..<count {
            release.signal()
        }
    }
}

private struct RecordingJumpRunner: TerminalJumpActionRunning {
    func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        .succeeded(action.handlerId ?? "jump")
    }
}
