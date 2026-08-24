import Darwin
import XCTest
@testable import MyVibeIslandCore

final class BridgeHealthAndJumpTargetTests: XCTestCase {
    func testBlockingRequestRegistersBeforeImmediateResolvePublication() {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handlerBox = BridgeHandlerBox()
        let once = RunOnce()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            sessionsDidChange: {
                guard once.claim() else { return }
                _ = handlerBox.handler?.handle(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "app",
                    source: "my-vibe-island",
                    requestId: nil,
                    command: .resolveAction,
                    payload: [
                        "requestId": .string("immediate-resolve"),
                        "sessionId": .string("race-session"),
                        "action": .string("approve"),
                    ]
                ))
            }
        )
        handlerBox.handler = handler

        let result = runBlockingHandler(handler, continuations: continuations, envelope: blockingEnvelope(
            requestId: "immediate-resolve"
        ))

        XCTAssertTrue(result.completedImmediately)
        XCTAssertNotNil(result.response?.sourceDirective)
    }

    func testIdlessCodexPermissionRequestWaitsForLocalApproval() {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handlerBox = BridgeHandlerBox()
        let once = RunOnce()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            sessionsDidChange: {
                guard once.claim() else { return }
                _ = handlerBox.handler?.handle(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "app",
                    source: "my-vibe-island",
                    requestId: nil,
                    command: .resolveAction,
                    payload: [
                        "requestId": .string("codex-terminal:live-session:live-turn"),
                        "sessionId": .string("codex-live-session"),
                        "action": .string("approve"),
                    ]
                ))
            }
        )
        handlerBox.handler = handler

        let result = runBlockingHandler(handler, continuations: continuations, envelope: BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("PermissionRequest"),
                "session_id": .string("live-session"),
                "turn_id": .string("live-turn"),
                "cwd": .string("/tmp/project"),
                "tool_name": .string("Bash"),
                "tool_input": .object([
                    "command": .string("/usr/bin/whoami"),
                    "description": .string("Do you approve running /usr/bin/whoami?"),
                ]),
            ]
        ))

        XCTAssertTrue(result.completedImmediately)
        XCTAssertEqual(result.response?.sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(["behavior": .string("allow")]),
            ]),
        ]))
    }

    func testIdlessCodexPermissionRequestHandsBackToTerminalAfterOwnershipDeadline() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations,
                terminalRoutedCodexApprovalHandoffDelay: 0.02
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let completed = expectation(description: "terminal-routed Codex hook released")
        let errorBox = ThreadSafeErrorBox()
        DispatchQueue.global().async {
            do {
                _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "hook",
                    source: "codex",
                    requestId: nil,
                    command: .hookEvent,
                    payload: [
                        "hook_event_name": .string("PermissionRequest"),
                        "session_id": .string("handoff-session"),
                        "turn_id": .string("handoff-turn"),
                        "cwd": .string("/tmp/project"),
                        "tool_name": .string("Bash"),
                    ]
                ))
            } catch {
                errorBox.set(error)
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)

        XCTAssertEqual(errorBox.value as? BridgeSocketError, .emptyResponse)
        XCTAssertEqual(continuations.pendingCount, 0)
        XCTAssertEqual(
            coordinator.actionableRequests().map(\.requestId),
            ["codex-terminal:handoff-session:handoff-turn"]
        )
        XCTAssertEqual(
            coordinator.snapshot(sessionId: "codex-handoff-session")?.pendingRequestIds,
            ["codex-terminal:handoff-session:handoff-turn"]
        )
    }

    func testBlockingRequestRegistersBeforeImmediateSessionEndPublication() {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handlerBox = BridgeHandlerBox()
        let once = RunOnce()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            sessionsDidChange: {
                guard once.claim() else { return }
                _ = handlerBox.handler?.handle(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "hook",
                    source: "codex",
                    requestId: nil,
                    command: .hookEvent,
                    payload: [
                        "rawEventName": .string("SessionEnd"),
                        "sessionId": .string("race-session"),
                        "cwd": .string("/tmp/project"),
                    ]
                ))
            }
        )
        handlerBox.handler = handler

        let result = runBlockingHandler(handler, continuations: continuations, envelope: blockingEnvelope(
            requestId: "immediate-session-end"
        ))

        XCTAssertTrue(result.completedImmediately)
        XCTAssertEqual(result.response, .ok(message: "event accepted"))
    }

    func testHealthProbeReturnsStructuredReachability() throws {
        let response = BridgeRequestHandler(sessionCoordinator: SessionCoordinator()).handle(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "diagnostic",
                source: "cursor",
                requestId: nil,
                command: .healthProbe,
                payload: try FixtureLoader.bridgePayload("runtime/health-probe")
            )
        )

        XCTAssertEqual(response, .ok(message: "health probe complete", sourceDirective: .object([
            "reachable": .bool(true),
            "hookInstalled": .null,
            "hashStatus": .string("notChecked"),
            "lastEventAt": .null,
            "originStatus": .string("recognized"),
        ])))
    }

    func testHealthProbeRejectsPathProbesUntrustedRolesAndUnknownSources() {
        let handler = BridgeRequestHandler(sessionCoordinator: SessionCoordinator())
        let pathProbe = healthEnvelope(payload: [
            "source": .string("cursor"),
            "configPath": .string("/etc/passwd"),
        ])
        let hookRole = healthEnvelope(clientRole: "hook", payload: ["source": .string("cursor")])
        let unknownSource = healthEnvelope(source: "unknown", payload: ["source": .string("unknown")])

        XCTAssertFalse(handler.handle(pathProbe).ok)
        XCTAssertFalse(handler.handle(hookRole).ok)
        XCTAssertFalse(handler.handle(unknownSource).ok)
    }

    func testUpdateJumpTargetPersistsAndPublishes() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "cursor", sessionId: "jump-session-1", cwd: "/tmp/jump-project"))
        let store = InMemorySessionStore()
        let publications = ThreadSafePublicationCount()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            sessionStore: store,
            sessionsDidChange: { publications.increment() }
        )

        let response = handler.handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "cursor",
            requestId: nil,
            command: .updateJumpTarget,
            payload: try FixtureLoader.bridgePayload("runtime/update-jump-target")
        ))

        XCTAssertEqual(response, .ok(message: "jump target updated"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "jump-session-1")?.jumpInput?.itermSessionId, "w0t1p2")
        XCTAssertEqual(coordinator.snapshot(sessionId: "jump-session-1")?.resolvedJumpTarget?.provenance, .processObservation)
        XCTAssertEqual(store.loadSnapshot().sessions.first?.jumpInput?.itermSessionId, "w0t1p2")
        XCTAssertEqual(publications.value, 1)
    }

    func testWeakerJumpTargetDoesNotReplaceExactStoredTarget() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "cursor", sessionId: "jump-session-1", cwd: "/tmp/jump-project"))
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        _ = handler.handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "cursor",
            requestId: nil,
            command: .updateJumpTarget,
            payload: try FixtureLoader.bridgePayload("runtime/update-jump-target")
        ))

        let response = handler.handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "cursor",
            requestId: nil,
            command: .updateJumpTarget,
            payload: [
                "sessionId": .string("jump-session-1"),
                "jumpInput": .object(["cwd": .string("/tmp/weaker")]),
                "confidence": .string("weak"),
                "source": .string("processScan"),
            ]
        ))

        XCTAssertEqual(response, .ok(message: "jump target updated"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "jump-session-1")?.jumpInput?.itermSessionId, "w0t1p2")
    }

    func testUpdateJumpTargetRejectsUntrustedRoleSourceAndExecutableFields() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "cursor", sessionId: "jump-session-1", cwd: "/tmp/project"))
        coordinator.apply(.sessionStarted(source: "unknown", sessionId: "unknown-session", cwd: "/tmp/project"))
        let publications = ThreadSafePublicationCount()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            sessionsDidChange: { publications.increment() }
        )
        let unsafeJump: [String: BridgeJSONValue] = [
            "sessionId": .string("jump-session-1"),
            "jumpInput": .object([
                "cwd": .string("/tmp/project"),
                "customJumpURL": .string("evil://execute"),
            ]),
            "confidence": .string("exact"),
            "source": .string("manual"),
        ]
        let unsafeSocketPath: [String: BridgeJSONValue] = [
            "sessionId": .string("jump-session-1"),
            "jumpInput": .object([
                "cwd": .string("/tmp/project"),
                "cmuxSocketPath": .string("/tmp/untrusted.sock"),
            ]),
        ]
        let unknownSource: [String: BridgeJSONValue] = [
            "sessionId": .string("unknown-session"),
            "jumpInput": .object(["cwd": .string("/tmp/project")]),
        ]

        XCTAssertFalse(handler.handle(jumpEnvelope(clientRole: "hook", source: "cursor", payload: unsafeJump)).ok)
        XCTAssertFalse(handler.handle(jumpEnvelope(clientRole: "watcher", source: "codex", payload: unsafeJump)).ok)
        XCTAssertFalse(handler.handle(jumpEnvelope(clientRole: "watcher", source: "cursor", payload: unsafeJump)).ok)
        XCTAssertFalse(handler.handle(jumpEnvelope(clientRole: "watcher", source: "cursor", payload: unsafeSocketPath)).ok)
        XCTAssertFalse(handler.handle(jumpEnvelope(clientRole: "watcher", source: "unknown", payload: unknownSource)).ok)
        XCTAssertNil(coordinator.snapshot(sessionId: "jump-session-1")?.jumpInput)
        XCTAssertNil(coordinator.snapshot(sessionId: "unknown-session")?.jumpInput)
        XCTAssertEqual(publications.value, 0)
    }

    func testUpdateJumpTargetIgnoresClaimedProvenanceAndConfidence() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "cursor", sessionId: "jump-session-1", cwd: "/tmp/project"))
        let response = BridgeRequestHandler(sessionCoordinator: coordinator).handle(jumpEnvelope(
            clientRole: "watcher",
            source: "cursor",
            payload: [
                "sessionId": .string("jump-session-1"),
                "jumpInput": .object(["cwd": .string("/tmp/derived")]),
                "confidence": .string("exact"),
                "source": .string("manual"),
            ]
        ))

        XCTAssertTrue(response.ok)
        XCTAssertEqual(coordinator.snapshot(sessionId: "jump-session-1")?.resolvedJumpTarget?.provenance, .processObservation)
        XCTAssertEqual(coordinator.snapshot(sessionId: "jump-session-1")?.resolvedJumpTarget?.strength, .weak)
    }

    func testBlockingContinuationTimeoutExpiryAndShutdownClearWaiters() {
        let continuations = PendingActionContinuations(timeout: 0.02)
        let timeoutRequest = request(id: "timeout")
        let expiryRequest = request(id: "expiry")
        let shutdownRequest = request(id: "shutdown")

        XCTAssertNil(continuations.wait(for: timeoutRequest))
        XCTAssertEqual(continuations.pendingCount, 0)

        assertCancellation(request: expiryRequest, continuations: continuations) {
            continuations.expire(sessionId: expiryRequest.sessionId, requestId: expiryRequest.requestId)
        }
        assertCancellation(request: shutdownRequest, continuations: continuations) {
            continuations.cancelAll()
        }
    }

    func testDuplicateBlockingWaitersBothReceiveResolvedDirective() {
        let continuations = PendingActionContinuations(timeout: 1)
        let duplicateRequest = request(id: "duplicate-resolve")
        let directive: BridgeJSONValue = .object(["decision": .string("allow")])
        let results = BridgeJSONValueResults()
        let completed = expectation(description: "duplicate waiters resolved")
        completed.expectedFulfillmentCount = 2

        for _ in 0..<2 {
            DispatchQueue.global().async {
                results.append(continuations.wait(for: duplicateRequest))
                completed.fulfill()
            }
        }

        waitUntil { continuations.pendingCount == 2 }
        XCTAssertTrue(continuations.resolve(
            sessionId: duplicateRequest.sessionId,
            requestId: duplicateRequest.requestId,
            directive: directive
        ))
        wait(for: [completed], timeout: 0.2)
        XCTAssertEqual(results.values, [directive, directive])
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    func testDuplicateBlockingWaitersBothReturnImmediatelyWhenExpired() {
        let continuations = PendingActionContinuations(timeout: 1)
        let duplicateRequest = request(id: "duplicate-expire")
        let results = BridgeJSONValueResults()
        let completed = expectation(description: "duplicate waiters expired")
        completed.expectedFulfillmentCount = 2

        for _ in 0..<2 {
            DispatchQueue.global().async {
                results.append(continuations.wait(for: duplicateRequest))
                completed.fulfill()
            }
        }

        waitUntil { continuations.pendingCount == 2 }
        continuations.expire(
            sessionId: duplicateRequest.sessionId,
            requestId: duplicateRequest.requestId
        )
        wait(for: [completed], timeout: 0.2)
        XCTAssertEqual(results.values, [nil, nil])
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    func testBlockingContinuationClearsWhenSocketClientDisconnects() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let continuations = PendingActionContinuations(timeout: 10)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: SessionCoordinator(),
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let clientFD = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(clientFD, 0)
        var address = try SocketAddress.unix(path: socketPath)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(clientFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(connected, 0)

        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "disconnect-request",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("disconnect-session"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )
        let line = try BridgeCodec().encodeEnvelopeLine(envelope)
        XCTAssertEqual(line.withCString { write(clientFD, $0, strlen($0)) }, line.utf8.count)
        waitUntil { continuations.pendingCount == 1 }

        close(clientFD)

        waitUntil { continuations.pendingCount == 0 }
    }

    func testCancellationBeforeRegistrationDoesNotPoisonFutureWaiter() {
        let continuations = PendingActionContinuations(timeout: 0.02)
        let futureRequest = request(id: "future")

        XCTAssertFalse(continuations.cancel(
            sessionId: futureRequest.sessionId,
            requestId: futureRequest.requestId
        ))

        let start = Date()
        XCTAssertNil(continuations.wait(for: futureRequest))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.015)
    }

    private func assertCancellation(
        request: ActionableRequest,
        continuations: PendingActionContinuations,
        cancel: () -> Void
    ) {
        let completed = expectation(description: "continuation cancelled")
        DispatchQueue.global().async {
            XCTAssertNil(continuations.wait(for: request, timeout: 1))
            completed.fulfill()
        }
        waitUntil { continuations.pendingCount == 1 }
        cancel()
        wait(for: [completed], timeout: 0.2)
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline, !predicate() {
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTAssertTrue(predicate())
    }

    private func request(id: String) -> ActionableRequest {
        ActionableRequest(
            requestId: id,
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Shell"
        )
    }

    private func blockingEnvelope(requestId: String) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: requestId,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("race-session"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )
    }

    private func runBlockingHandler(
        _ handler: BridgeRequestHandler,
        continuations: PendingActionContinuations,
        envelope: BridgeEnvelope
    ) -> (completedImmediately: Bool, response: BridgeResponse?) {
        let completed = DispatchGroup()
        let response = BridgeResponseBox()
        completed.enter()
        DispatchQueue.global().async {
            response.set(handler.handle(envelope))
            completed.leave()
        }
        let completedImmediately = completed.wait(timeout: .now() + 0.2) == .success
        if !completedImmediately {
            continuations.cancelAll()
            _ = completed.wait(timeout: .now() + 0.2)
        }
        return (completedImmediately, response.value)
    }

    private func healthEnvelope(
        clientRole: String = "diagnostic",
        source: String = "cursor",
        payload: [String: BridgeJSONValue]
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: clientRole,
            source: source,
            requestId: nil,
            command: .healthProbe,
            payload: payload
        )
    }

    private func jumpEnvelope(
        clientRole: String,
        source: String,
        payload: [String: BridgeJSONValue]
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: clientRole,
            source: source,
            requestId: nil,
            command: .updateJumpTarget,
            payload: payload
        )
    }
}

private final class ThreadSafePublicationCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private final class BridgeHandlerBox: @unchecked Sendable {
    var handler: BridgeRequestHandler?
}

private final class BridgeResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var response: BridgeResponse?

    var value: BridgeResponse? {
        lock.withLock { response }
    }

    func set(_ response: BridgeResponse) {
        lock.withLock { self.response = response }
    }
}

private final class ThreadSafeErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?

    var value: Error? {
        lock.withLock { error }
    }

    func set(_ error: Error) {
        lock.withLock { self.error = error }
    }
}

private final class RunOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.withLock {
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }
}

private final class BridgeJSONValueResults: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [BridgeJSONValue?] = []

    var values: [BridgeJSONValue?] {
        lock.withLock { results }
    }

    func append(_ result: BridgeJSONValue?) {
        lock.withLock { results.append(result) }
    }
}
