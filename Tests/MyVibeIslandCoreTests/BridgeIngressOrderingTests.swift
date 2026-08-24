import Foundation
import XCTest
@testable import MyVibeIslandCore

final class BridgeIngressOrderingTests: XCTestCase {
    func testSameSessionIngressAppliesInArrivalOrderWhenEarlierAdapterWorkIsBlocked() throws {
        let firstAdapterEntered = DispatchSemaphore(value: 0)
        let releaseFirstAdapter = DispatchSemaphore(value: 0)
        let adapter = BlockingFirstPromptAdapter(
            firstAdapterEntered: firstAdapterEntered,
            releaseFirstAdapter: releaseFirstAdapter
        )
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            adapterRegistry: AgentAdapterRegistry(adapters: [adapter])
        )
        let firstFinished = expectation(description: "first hook finishes")
        let secondFinished = expectation(description: "second hook finishes")

        DispatchQueue.global().async {
            _ = handler.handle(Self.hookEnvelope(eventName: "UserPromptSubmit", message: "First prompt"))
            firstFinished.fulfill()
        }

        XCTAssertEqual(firstAdapterEntered.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async {
            XCTAssertTrue(handler.handle(Self.hookEnvelope(eventName: "Stop", message: "Second completion")).ok)
            secondFinished.fulfill()
        }

        releaseFirstAdapter.signal()
        wait(for: [firstFinished, secondFinished], timeout: 1)

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "ordered-session"))
        XCTAssertEqual(session.reportedStatus, .completed)
        XCTAssertTrue(session.hasUnreadCompletion)
        XCTAssertEqual(session.lastAssistantMessage, "Second completion")
    }

    private static func hookEnvelope(eventName: String, message: String) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "ordering-test",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "eventName": .string(eventName),
                "sessionId": .string("ordered-session"),
                "message": .string(message),
            ]
        )
    }
}

private final class BlockingFirstPromptAdapter: AgentAdapter, @unchecked Sendable {
    let sourceIds: Set<String> = ["ordering-test"]
    private let firstAdapterEntered: DispatchSemaphore
    private let releaseFirstAdapter: DispatchSemaphore

    init(firstAdapterEntered: DispatchSemaphore, releaseFirstAdapter: DispatchSemaphore) {
        self.firstAdapterEntered = firstAdapterEntered
        self.releaseFirstAdapter = releaseFirstAdapter
    }

    func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard case let .string(eventName)? = envelope.payload["eventName"],
              case let .string(sessionId)? = envelope.payload["sessionId"],
              case let .string(message)? = envelope.payload["message"] else {
            throw AgentAdapterError.invalidHookPayload
        }

        if eventName == "UserPromptSubmit" {
            firstAdapterEntered.signal()
            _ = releaseFirstAdapter.wait(timeout: .now() + 1)
        }

        return HookEvent(
            rawEventName: eventName,
            source: envelope.source,
            sessionId: sessionId,
            cwd: "/tmp/ordered-session",
            message: message
        )
    }

    func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        .none
    }
}
