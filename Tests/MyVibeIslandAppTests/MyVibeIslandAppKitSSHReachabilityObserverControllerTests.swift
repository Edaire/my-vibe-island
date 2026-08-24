import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHReachabilityObserverControllerTests: XCTestCase {
    @MainActor
    func testSSHReachabilityObserverControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHReachabilityObserverControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-reachability-observer-controller-matrix")
        )
        let unchanged = observer(result: .heartbeatTimeout, reachability: .unsatisfied, failureCount: 2)

        let actual = SSHReachabilityObserverControllerMatrixFixture(rows: [
            row(
                id: "publish-changed-observer",
                initial: observer(result: .notStarted, reachability: .unknown, failureCount: 0),
                observations: [observer(result: .succeeded, reachability: .satisfied, failureCount: 0, lastSuccessAt: "2026-07-09T10:00:00Z")]
            ),
            row(id: "suppress-unchanged-observer", initial: unchanged, observations: [unchanged]),
            row(
                id: "publish-first-observer",
                initial: nil,
                observations: [observer(result: .networkUnsatisfied, reachability: .unsatisfied, failureCount: 1)]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPublishesObserverWhenReachabilityChanges() {
        var published: [SSHReachabilityState] = []
        let initial = observer(
            result: .notStarted,
            reachability: .unknown,
            failureCount: 0
        )
        let controller = MyVibeIslandAppKitSSHReachabilityObserverController(
            currentObserver: initial,
            publishReachabilityDidChange: { observer in
                published.append(observer.currentReachability)
            }
        )
        let changed = observer(
            result: .succeeded,
            reachability: .satisfied,
            failureCount: 0,
            lastSuccessAt: "2026-07-09T10:00:00Z"
        )

        let didPublish = controller.observe(changed)

        XCTAssertTrue(didPublish)
        XCTAssertEqual(controller.currentObserver, changed)
        XCTAssertEqual(controller.lastPublishedObserver, changed)
        XCTAssertNil(controller.lastFailureKind)
        XCTAssertEqual(published, [.satisfied])
    }

    @MainActor
    func testControllerDoesNotPublishUnchangedObserver() {
        var published: [SSHReachabilityObserver] = []
        let current = observer(
            result: .heartbeatTimeout,
            reachability: .unsatisfied,
            failureCount: 2
        )
        let controller = MyVibeIslandAppKitSSHReachabilityObserverController(
            currentObserver: current,
            publishReachabilityDidChange: { observer in
                published.append(observer)
            }
        )

        let didPublish = controller.observe(current)

        XCTAssertFalse(didPublish)
        XCTAssertEqual(controller.currentObserver, current)
        XCTAssertNil(controller.lastPublishedObserver)
        XCTAssertEqual(controller.lastFailureKind, .heartbeatTimeout)
        XCTAssertEqual(published, [])
    }

    @MainActor
    func testControllerPublishesFirstObservedReachabilitySnapshot() {
        var publishedHostIds: [String] = []
        let controller = MyVibeIslandAppKitSSHReachabilityObserverController(
            publishReachabilityDidChange: { observer in
                publishedHostIds.append(observer.hostId)
            }
        )
        let current = observer(
            result: .networkUnsatisfied,
            reachability: .unsatisfied,
            failureCount: 1
        )

        let didPublish = controller.observe(current)

        XCTAssertTrue(didPublish)
        XCTAssertEqual(controller.currentObserver, current)
        XCTAssertEqual(controller.lastPublishedObserver, current)
        XCTAssertEqual(controller.lastFailureKind, .hostUnreachable)
        XCTAssertEqual(publishedHostIds, ["devbox"])
    }

    private func observer(
        result: SSHReachabilityProbeResult,
        reachability: SSHReachabilityState,
        failureCount: Int,
        lastSuccessAt: String? = nil
    ) -> SSHReachabilityObserver {
        SSHReachabilityObserver(
            hostId: "devbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: true,
            didFireEarlyHeartbeat: false,
            lastProbeResult: result,
            lastSuccessAt: lastSuccessAt,
            failureCount: failureCount,
            reconnectAttempt: failureCount,
            currentReachability: reachability,
            nextReconnectAt: failureCount > 0 ? "2026-07-09T10:01:00Z" : nil,
            userDisconnected: false
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: SSHReachabilityObserver?,
        observations: [SSHReachabilityObserver]
    ) -> SSHReachabilityObserverControllerMatrixRow {
        var events: [SSHReachabilityObserverSummary] = []
        let controller = MyVibeIslandAppKitSSHReachabilityObserverController(
            currentObserver: initial,
            publishReachabilityDidChange: { events.append(SSHReachabilityObserverSummary($0)) }
        )
        let didPublish = observations.map(controller.observe)

        return SSHReachabilityObserverControllerMatrixRow(
            id: id,
            didPublish: didPublish,
            currentObserver: controller.currentObserver.map(SSHReachabilityObserverSummary.init),
            lastPublishedObserver: controller.lastPublishedObserver.map(SSHReachabilityObserverSummary.init),
            lastFailureKind: controller.lastFailureKind?.rawValue,
            events: events
        )
    }
}

private struct SSHReachabilityObserverControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHReachabilityObserverControllerMatrixRow]
}

private struct SSHReachabilityObserverControllerMatrixRow: Codable, Equatable {
    let id: String
    let didPublish: [Bool]
    let currentObserver: SSHReachabilityObserverSummary?
    let lastPublishedObserver: SSHReachabilityObserverSummary?
    let lastFailureKind: String?
    let events: [SSHReachabilityObserverSummary]
}

private struct SSHReachabilityObserverSummary: Codable, Equatable {
    let hostId: String
    let lastProbeResult: String
    let currentReachability: String
    let failureCount: Int
    let lastSuccessAt: String?
    let nextReconnectAt: String?

    init(_ observer: SSHReachabilityObserver) {
        self.hostId = observer.hostId
        self.lastProbeResult = observer.lastProbeResult.rawValue
        self.currentReachability = observer.currentReachability.rawValue
        self.failureCount = observer.failureCount
        self.lastSuccessAt = observer.lastSuccessAt
        self.nextReconnectAt = observer.nextReconnectAt
    }
}
