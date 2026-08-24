import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRuntimeOwnerControllerTests: XCTestCase {
    @MainActor
    func testRuntimeOwnerControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RuntimeOwnerControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/runtime-owner-controller-matrix")
        )

        let actual = RuntimeOwnerControllerMatrixFixture(rows: [
            row(
                id: "start-stop-sequence",
                actions: [
                    .start(.bridgeServer),
                    .start(.sessionCoordinator),
                    .stop(.bridgeServer)
                ]
            ),
            row(
                id: "duplicate-start-and-missing-stop",
                actions: [
                    .start(.usageCoordinator),
                    .start(.usageCoordinator),
                    .stop(.diagnosticsCoordinator)
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerStartsAndStopsRuntimeOwnersThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { owner in
                events.append("start:\(owner.rawValue)")
            },
            stopOwner: { owner in
                events.append("stop:\(owner.rawValue)")
            }
        )

        controller.start(.bridgeServer)
        controller.start(.sessionCoordinator)
        controller.stop(.bridgeServer)

        XCTAssertEqual(controller.runningOwners, [.sessionCoordinator])
        XCTAssertEqual(events, [
            "start:bridgeServer",
            "start:sessionCoordinator",
            "stop:bridgeServer"
        ])
    }

    @MainActor
    func testControllerPublishesLastRuntimeOwnerActionForOrchestration() {
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { _ in },
            stopOwner: { _ in }
        )

        controller.start(.bridgeServer)

        XCTAssertEqual(controller.lastAction, .start(.bridgeServer))

        controller.stop(.bridgeServer)

        XCTAssertEqual(controller.lastAction, .stop(.bridgeServer))
    }

    @MainActor
    func testFailedStartDoesNotMarkOwnerRunningAndStoresRedactedFailure() {
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { owner in
                if owner == .bridgeServer {
                    throw RuntimeOwnerTestError.failed("private socket path")
                }
            }
        )

        controller.start(.bridgeServer)

        XCTAssertFalse(controller.runningOwners.contains(.bridgeServer))
        XCTAssertEqual(controller.lastAction, .startFailed(.bridgeServer))
        XCTAssertNotNil(controller.failures[.bridgeServer])
        XCTAssertFalse(controller.failures[.bridgeServer]?.contains("private socket path") == true)
    }

    @MainActor
    func testDuplicateStartAndMissingStopDoNotRepeatCallbacks() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { events.append("start:\($0.rawValue)") },
            stopOwner: { events.append("stop:\($0.rawValue)") }
        )

        controller.start(.bridgeServer)
        controller.start(.bridgeServer)
        controller.stop(.diagnosticsCoordinator)
        controller.stop(.bridgeServer)

        XCTAssertEqual(events, ["start:bridgeServer", "stop:bridgeServer"])
        XCTAssertEqual(controller.runningOwners, [])
        XCTAssertEqual(controller.failures, [:])
    }

    @MainActor
    func testUnavailableOwnerIsVisibleAndNeverReportedRunning() {
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            unavailableOwners: [.usageCoordinator: "usage runtime is not implemented"]
        )

        controller.start(.usageCoordinator)

        XCTAssertEqual(controller.availability(of: .usageCoordinator), .unavailable("usage runtime is not implemented"))
        XCTAssertFalse(controller.runningOwners.contains(.usageCoordinator))
        XCTAssertEqual(controller.failures[.usageCoordinator], "usage runtime is not implemented")
    }

    @MainActor
    func testStopAllRunningOwnersUsesReverseStartupOrder() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { events.append("start:\($0.rawValue)") },
            stopOwner: { events.append("stop:\($0.rawValue)") }
        )

        controller.start(.bridgeServer)
        controller.start(.integrationCoordinator)
        controller.stopAll()

        XCTAssertEqual(events, [
            "start:bridgeServer",
            "start:integrationCoordinator",
            "stop:integrationCoordinator",
            "stop:bridgeServer"
        ])
    }

    @MainActor
    private func row(
        id: String,
        actions: [RuntimeOwnerControllerFixtureAction]
    ) -> RuntimeOwnerControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { owner in
                events.append("start:\(owner.rawValue)")
            },
            stopOwner: { owner in
                events.append("stop:\(owner.rawValue)")
            }
        )

        for action in actions {
            switch action {
            case let .start(owner):
                controller.start(owner)
            case let .stop(owner):
                controller.stop(owner)
            }
        }

        return RuntimeOwnerControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            runningOwners: controller.runningOwners.map(\.rawValue),
            lastAction: controller.lastAction?.summary,
            events: events
        )
    }
}

private enum RuntimeOwnerTestError: Error {
    case failed(String)
}

private struct RuntimeOwnerControllerMatrixFixture: Codable, Equatable {
    let rows: [RuntimeOwnerControllerMatrixRow]
}

private struct RuntimeOwnerControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let runningOwners: [String]
    let lastAction: String?
    let events: [String]
}

private enum RuntimeOwnerControllerFixtureAction {
    case start(AppRuntimeOwner)
    case stop(AppRuntimeOwner)

    var summary: String {
        switch self {
        case let .start(owner):
            return "start:\(owner.rawValue)"
        case let .stop(owner):
            return "stop:\(owner.rawValue)"
        }
    }
}

private extension MyVibeIslandAppKitRuntimeOwnerAction {
    var summary: String {
        switch self {
        case let .start(owner):
            return "start:\(owner.rawValue)"
        case let .startFailed(owner):
            return "startFailed:\(owner.rawValue)"
        case let .stop(owner):
            return "stop:\(owner.rawValue)"
        }
    }
}
