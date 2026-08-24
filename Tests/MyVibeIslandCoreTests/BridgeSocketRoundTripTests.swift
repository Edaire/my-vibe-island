import Darwin
import Foundation
import XCTest
@testable import MyVibeIslandCore

final class BridgeSocketRoundTripTests: XCTestCase {
    private struct ShortTimeoutCodexAdapter: AgentAdapter {
        let sourceIds: Set<String> = ["codex"]
        private let codexAdapter = CodexAdapter()

        func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
            try codexAdapter.hookEvent(from: envelope)
        }

        func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
            codexAdapter.directive(for: request, resolution: resolution)
        }

        func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
            request.kind == .permission ? 0.05 : nil
        }
    }

    private final class ResponseBox: @unchecked Sendable {
        private let lock = NSLock()
        private var response: BridgeResponse?
        private var error: Error?

        func record(_ result: Result<BridgeResponse, Error>) {
            lock.lock()
            switch result {
            case let .success(response):
                self.response = response
            case let .failure(error):
                self.error = error
            }
            lock.unlock()
        }

        func get() throws -> BridgeResponse {
            lock.lock()
            defer {
                lock.unlock()
            }

            if let error {
                throw error
            }
            return try XCTUnwrap(response)
        }
    }

    private func helloResponse(socketPath: String) throws -> BridgeResponse {
        try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(schemaVersion: 1, clientRole: "hook", source: "codex", requestId: nil, command: .hello, payload: [:])
        )
    }

    func testTemporaryForTestsReturnsUniqueTmpSocketPaths() {
        let first = BridgeSocketPath.temporaryForTests()
        let second = BridgeSocketPath.temporaryForTests()

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("/tmp/"))
        XCTAssertTrue(second.hasPrefix("/tmp/"))
        XCTAssertTrue(first.hasSuffix(".sock"))
        XCTAssertTrue(second.hasSuffix(".sock"))
    }

    func testDefaultPathUsesMyVibeIslandSocketNamespace() {
        XCTAssertEqual(
            BridgeSocketPath.defaultPath(homeDirectory: URL(fileURLWithPath: "/Users/tester")),
            "/Users/tester/.my-vibe-island/run/my-vibe-island.sock"
        )
    }

    func testDefaultPathUsesOriginalSocketEnvironmentOverrideName() {
        XCTAssertEqual(
            BridgeSocketPath.defaultPath(
                processEnvironment: [BridgeRuntimeContract.socketEnvironmentVariable: "/tmp/custom.sock"],
                homeDirectory: URL(fileURLWithPath: "/Users/tester")
            ),
            "/tmp/custom.sock"
        )
    }

    func testClientServerHelloRoundTrip() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let response = try helloResponse(socketPath: socketPath)

        XCTAssertEqual(response, .ok(message: "bridge reachable"))
    }

    func testFireAndForgetClientDoesNotWaitForServerResponse() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(listener, 0)
        defer {
            close(listener)
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        var address = try SocketAddress.unix(path: socketPath)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(listener, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(listener, 1), 0)

        let accepted = expectation(description: "server accepts fire-and-forget event")
        DispatchQueue.global().async {
            let client = accept(listener, nil, nil)
            if client >= 0 {
                _ = try? SocketIO.readLine(from: client)
                accepted.fulfill()
                Thread.sleep(forTimeInterval: 1)
                close(client)
            }
        }

        let start = Date()
        try BridgeClient(socketPath: socketPath).sendFireAndForget(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: ["hook_event_name": .string("PostToolUse")]
            )
        )

        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        wait(for: [accepted], timeout: 1.0)
    }

    func testStopReturnsWithConnectedIdleClient() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let clientFD = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(clientFD, 0)
        defer {
            close(clientFD)
        }

        var address = try SocketAddress.unix(path: socketPath)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(clientFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(connected, 0)

        let stopped = expectation(description: "server stop returns with idle client")
        DispatchQueue.global().async {
            server.stop()
            stopped.fulfill()
        }

        wait(for: [stopped], timeout: 1.0)
    }

    func testServerHandlesSecondClientWhileFirstClientIsIdle() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let idleFD = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(idleFD, 0)
        defer {
            close(idleFD)
        }

        var address = try SocketAddress.unix(path: socketPath)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(idleFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(connected, 0)

        let start = Date()
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.05)
    }

    func testStartingServerTwiceThrowsAndOriginalServerStillResponds() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        XCTAssertThrowsError(try server.start()) { error in
            XCTAssertEqual(error as? BridgeSocketError, .alreadyRunning)
        }

        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testOversizedFrameIsClosedAndReleasesConnectionSlot() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()),
            frameByteLimit: 128,
            maxConcurrentClients: 1
        )
        try server.start()
        defer { server.stop() }

        let fd = try connectedSocket(path: socketPath)
        try SocketIO.writeAll(String(repeating: "x", count: 129) + "\n", to: fd)
        XCTAssertTrue(waitForEOF(fd))
        close(fd)
        XCTAssertTrue(waitUntil { server.activeClientCount == 0 })
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testMissingNewlineFrameIsClosedAndReleasesConnectionSlot() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()),
            frameByteLimit: 256,
            maxConcurrentClients: 1
        )
        try server.start()
        defer { server.stop() }

        let fd = try connectedSocket(path: socketPath)
        try SocketIO.writeAll("{\"schemaVersion\":1", to: fd)
        XCTAssertTrue(waitForEOF(fd))
        close(fd)
        XCTAssertTrue(waitUntil { server.activeClientCount == 0 })
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testConcurrentConnectionLimitRejectsExcessAndRecoversSlot() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()),
            frameByteLimit: 256,
            maxConcurrentClients: 1
        )
        try server.start()
        defer { server.stop() }

        let firstFD = try connectedSocket(path: socketPath)
        XCTAssertTrue(waitUntil { server.activeClientCount == 1 })
        let secondFD = try connectedSocket(path: socketPath)
        XCTAssertTrue(waitForEOF(secondFD))
        close(secondFD)
        close(firstFD)
        XCTAssertTrue(waitUntil { server.activeClientCount == 0 })
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testOverlongSocketPathThrowsAndSubsequentValidServerStillResponds() throws {
        let overlongPath = "/tmp/" + String(repeating: "a", count: 200) + ".sock"

        let invalidServer = BridgeServer(socketPath: overlongPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        XCTAssertThrowsError(try invalidServer.start()) { error in
            XCTAssertEqual(error as? BridgeSocketError, .pathTooLong(overlongPath))
        }

        let socketPath = BridgeSocketPath.temporaryForTests()
        let validServer = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try validServer.start()
        defer {
            validServer.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testClientServerHookEventSessionStartUpdatesSharedSessionCoordinator() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: coordinator))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("SessionStart"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project")
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.source, "codex")
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.cwd, "/tmp/project")
    }

    func testHookEventResponseDoesNotWaitForSessionPublication() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let publicationEntered = DispatchSemaphore(value: 0)
        let releasePublication = DispatchSemaphore(value: 0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: SessionCoordinator(),
                sessionsDidChange: {
                    publicationEntered.signal()
                    _ = releasePublication.wait(timeout: .now() + 2)
                }
            )
        )
        try server.start()
        defer {
            releasePublication.signal()
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let startedAt = Date()
        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("PostToolUse"),
                    "sessionId": .string("post-tool-publication-probe"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Bash"),
                    "lastAssistantMessage": .string("done")
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.5)
        XCTAssertEqual(publicationEntered.wait(timeout: .now() + 1), .success)
    }

    func testOriginalVibeIslandBridgeRawHookUpdatesSharedSessionCoordinator() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: coordinator))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let fd = try connectedSocket(path: socketPath)
        defer { close(fd) }
        let request = #"{"session_id":"codex-compat-probe","hook_event_name":"SessionStart","_source":"codex","cwd":"/tmp/compat-probe","codex_thread_id":"compat-probe","codex_event_type":"hook-session-start"}"# + "\n"
        try SocketIO.writeAll(request, to: fd)
        _ = try SocketIO.readLine(from: fd)

        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-compat-probe")?.source, "codex")
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-compat-probe")?.cwd, "/tmp/compat-probe")
    }

    func testBlockingPermissionRequestReturnsDirectiveAfterResolveAction() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 1.0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "blocking hook request completed")
        let hookResponse = ResponseBox()
        DispatchQueue.global().async {
            do {
                let response = try BridgeClient(socketPath: socketPath).send(
                    BridgeEnvelope(
                        schemaVersion: 1,
                        clientRole: "hook",
                        source: "codex",
                        requestId: "r1",
                        command: .hookEvent,
                        payload: [
                            "rawEventName": .string("PermissionRequest"),
                            "sessionId": .string("s1"),
                            "cwd": .string("/tmp/project"),
                            "toolName": .string("Shell"),
                        ]
                    )
                )
                hookResponse.record(.success(response))
            } catch {
                hookResponse.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "pending action appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == "r1" }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        let resolveResponse = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "app",
                source: "my-vibe-island",
                requestId: nil,
                command: .resolveAction,
                payload: [
                    "requestId": .string("r1"),
                    "sessionId": .string("s1"),
                    "action": .string("approve"),
                ]
            )
        )

        XCTAssertNotNil(resolveResponse.sourceDirective)
        wait(for: [hookCompleted], timeout: 1.1)
        XCTAssertEqual(try hookResponse.get().sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ]))
    }

    func testBlockingPermissionRequestTimesOutFailOpenWithoutDirective() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 0.05)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                adapterRegistry: AgentAdapterRegistry(adapters: [ShortTimeoutCodexAdapter()]),
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: "r1",
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("PermissionRequest"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Shell"),
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.actionableRequests().map(\.requestId), ["r1"])
    }

    func testSessionEndHookExpiresBlockingContinuationOverSocket() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "blocking hook released by session end")
        DispatchQueue.global().async {
            _ = try? BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: "expiry-request",
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("PermissionRequest"),
                    "sessionId": .string("expiry-session"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Shell"),
                ]
            ))
            hookCompleted.fulfill()
        }
        let pendingDeadline = Date().addingTimeInterval(0.2)
        while Date() < pendingDeadline, continuations.pendingCount == 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTAssertEqual(continuations.pendingCount, 1)

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionEnd"),
                "sessionId": .string("expiry-session"),
                "cwd": .string("/tmp/project"),
            ]
        ))

        let expiryDeadline = Date().addingTimeInterval(0.2)
        while Date() < expiryDeadline, continuations.pendingCount != 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }
        let expiredBeforeShutdown = continuations.pendingCount == 0
        if !expiredBeforeShutdown {
            server.stop()
        }
        wait(for: [hookCompleted], timeout: 0.4)
        XCTAssertTrue(expiredBeforeShutdown)
    }

    func testStopHookRespondsPromptlyWhileManyPermissionHooksAreAwaitingResolution() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 60)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        for index in 0..<30 {
            DispatchQueue.global().async {
                _ = try? BridgeClient(socketPath: socketPath).send(
                    BridgeEnvelope(
                        schemaVersion: 1,
                        clientRole: "hook",
                        source: "codex",
                        requestId: "pending-\(index)",
                        command: .hookEvent,
                        payload: [
                            "rawEventName": .string("PermissionRequest"),
                            "sessionId": .string("pending-session-\(index)"),
                            "cwd": .string("/tmp/project"),
                            "toolName": .string("Shell"),
                        ]
                    )
                )
            }
        }

        XCTAssertTrue(waitUntil { continuations.pendingCount == 30 })

        let startedAt = Date()
        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("Stop"),
                    "sessionId": .string("completed-session"),
                    "cwd": .string("/tmp/project"),
                    "message": .string("completed"),
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)
    }

    func testDismissResolutionExpiresBlockingContinuationOverSocket() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "blocking hook released by dismiss")
        DispatchQueue.global().async {
            _ = try? BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: "dismiss-request",
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("PermissionRequest"),
                    "sessionId": .string("dismiss-session"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Shell"),
                ]
            ))
            hookCompleted.fulfill()
        }
        let pendingDeadline = Date().addingTimeInterval(0.2)
        while Date() < pendingDeadline, continuations.pendingCount == 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTAssertEqual(continuations.pendingCount, 1)

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: [
                "requestId": .string("dismiss-request"),
                "sessionId": .string("dismiss-session"),
                "action": .string("dismiss"),
            ]
        ))

        let expiryDeadline = Date().addingTimeInterval(0.2)
        while Date() < expiryDeadline, continuations.pendingCount != 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }
        let expiredBeforeShutdown = continuations.pendingCount == 0
        if !expiredBeforeShutdown {
            server.stop()
        }
        wait(for: [hookCompleted], timeout: 0.4)
        XCTAssertTrue(expiredBeforeShutdown)
    }

    func testClaudeCompatibleBlockingPermissionRequestReturnsAllowDirectiveAfterApproval() throws {
        let result = try claudeCompatibleBlockingPermissionResponse(action: "approve")

        XCTAssertEqual(result.sourceDirective, .object([
            "continue": .bool(true),
            "suppressOutput": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([:]),
                    "updatedPermissions": .array([]),
                ]),
            ]),
        ]))
    }

    func testClaudeCompatibleBlockingPermissionRequestReturnsDenyDirectiveAfterDenial() throws {
        let result = try claudeCompatibleBlockingPermissionResponse(action: "deny")

        XCTAssertEqual(result.sourceDirective, .object([
            "continue": .bool(true),
            "suppressOutput": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("deny"),
                    "message": .string("User denied the permission request"),
                    "interrupt": .bool(false),
                ]),
            ]),
        ]))
    }

    func testOpenCodeBlockingPermissionRequestReturnsAllowDirectiveAfterApproval() throws {
        let result = try opencodeBlockingResponse(
            hookPayload: [
                "event": .string("permission"),
                "id": .string("opencode-permission-1"),
                "sessionID": .string("opencode-session"),
                "permission": .string("bash"),
            ],
            requestId: "opencode-permission-1",
            action: "approve"
        )

        XCTAssertEqual(result.sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(["behavior": .string("allow")]),
            ]),
        ]))
    }

    func testOpenCodeBlockingQuestionRequestReturnsAnswerDirectiveAfterAnswer() throws {
        let result = try opencodeBlockingResponse(
            hookPayload: [
                "event": .string("question"),
                "id": .string("opencode-question-1"),
                "sessionID": .string("opencode-session"),
            ],
            requestId: "opencode-question-1",
            action: "answer",
            selection: "Use option A"
        )

        XCTAssertEqual(result.sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([
                        "answers": .object(["Question": .string("Use option A")]),
                    ]),
                ]),
            ]),
        ]))
    }

    private func claudeCompatibleBlockingPermissionResponse(action: String) throws -> BridgeResponse {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 1.0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "claude-compatible blocking hook completed")
        let hookResponse = ResponseBox()
        DispatchQueue.global().async {
            do {
                let response = try BridgeClient(socketPath: socketPath).send(
                    BridgeEnvelope(
                        schemaVersion: 1,
                        clientRole: "hook",
                        source: "claude",
                        requestId: nil,
                        command: .hookEvent,
                        payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
                    )
                )
                hookResponse.record(.success(response))
            } catch {
                hookResponse.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "claude-compatible pending action appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == "tool-use-claude-1" }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        _ = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "app",
                source: "my-vibe-island",
                requestId: nil,
                command: .resolveAction,
                payload: [
                    "requestId": .string("tool-use-claude-1"),
                    "sessionId": .string("claude-session"),
                    "action": .string(action),
                ]
            )
        )

        wait(for: [hookCompleted], timeout: 1.1)
        return try hookResponse.get()
    }

    private func opencodeBlockingResponse(
        hookPayload: [String: BridgeJSONValue],
        requestId: String,
        action: String,
        selection: String? = nil
    ) throws -> BridgeResponse {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 1.0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "opencode blocking hook completed")
        let hookResponse = ResponseBox()
        DispatchQueue.global().async {
            do {
                let response = try BridgeClient(socketPath: socketPath).send(
                    BridgeEnvelope(
                        schemaVersion: 1,
                        clientRole: "hook",
                        source: "opencode",
                        requestId: nil,
                        command: .hookEvent,
                        payload: hookPayload
                    )
                )
                hookResponse.record(.success(response))
            } catch {
                hookResponse.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "opencode pending action appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == requestId }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        var payload: [String: BridgeJSONValue] = [
            "requestId": .string(requestId),
            "sessionId": .string("opencode-session"),
            "action": .string(action),
        ]
        if let selection {
            payload["answer"] = .string(selection)
        }

        _ = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "app",
                source: "my-vibe-island",
                requestId: nil,
                command: .resolveAction,
                payload: payload
            )
        )

        wait(for: [hookCompleted], timeout: 1.1)
        return try hookResponse.get()
    }

    private func connectedSocket(path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        var address = try SocketAddress.unix(path: path)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(connected, 0)
        return fd
    }

    private func waitForEOF(_ fd: Int32) -> Bool {
        SocketIO.setReadTimeout(on: fd, seconds: 0, microseconds: 500_000)
        var buffer = [UInt8](repeating: 0, count: 256)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count == 0 { return true }
            if count < 0 { return false }
        }
    }

    private func waitUntil(_ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            if predicate() { return true }
            Thread.sleep(forTimeInterval: 0.005)
        }
        return predicate()
    }
}
