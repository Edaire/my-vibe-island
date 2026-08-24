import XCTest
@testable import MyVibeIslandCore

final class SSHReachabilityObserverTests: XCTestCase {
    func testSSHReachabilityObserverMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHReachabilityObserverMatrixFixture.self,
            from: try FixtureLoader.data("remote/ssh-reachability-observer-matrix")
        )

        let actual = SSHReachabilityObserverMatrixFixture(
            idaAlias: SSHReachabilityObserver.idaAlias,
            rows: [
                row(id: "not-started-default", observer: SSHReachabilityObserver(
                    hostId: "devbox",
                    heartbeatIntervalSeconds: 15,
                    heartbeatTimeoutSeconds: 5
                )),
                row(id: "succeeded-active-heartbeat", observer: SSHReachabilityObserver(
                    hostId: "devbox",
                    heartbeatIntervalSeconds: 15,
                    heartbeatTimeoutSeconds: 5,
                    heartbeatTimerActive: true,
                    didFireEarlyHeartbeat: true,
                    lastProbeResult: .succeeded,
                    lastSuccessAt: "2026-07-09T04:00:00Z",
                    failureCount: 0,
                    reconnectAttempt: 1,
                    currentReachability: .satisfied,
                    nextReconnectAt: "2026-07-09T04:05:00Z"
                )),
                row(id: "network-unsatisfied", observer: SSHReachabilityObserver(
                    hostId: "labbox",
                    heartbeatIntervalSeconds: 30,
                    heartbeatTimeoutSeconds: 10,
                    lastProbeResult: .networkUnsatisfied,
                    failureCount: 1,
                    currentReachability: .unsatisfied
                )),
                row(id: "heartbeat-timeout-user-disconnected", observer: SSHReachabilityObserver(
                    hostId: "labbox",
                    heartbeatIntervalSeconds: 30,
                    heartbeatTimeoutSeconds: 10,
                    lastProbeResult: .heartbeatTimeout,
                    failureCount: 2,
                    currentReachability: .unsatisfied,
                    userDisconnected: true
                )),
                row(id: "command-failed-reconnect-scheduled", observer: SSHReachabilityObserver(
                    hostId: "buildbox",
                    heartbeatIntervalSeconds: 20,
                    heartbeatTimeoutSeconds: 6,
                    lastProbeResult: .commandFailed,
                    failureCount: 3,
                    reconnectAttempt: 2,
                    currentReachability: .unknown,
                    nextReconnectAt: "2026-07-09T04:10:00Z"
                )),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testReachabilityObserverRoundTripsHeartbeatState() throws {
        let observer = SSHReachabilityObserver(
            hostId: "devbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: true,
            didFireEarlyHeartbeat: true,
            lastProbeResult: .succeeded,
            lastSuccessAt: "2026-07-08T22:20:00Z",
            failureCount: 0,
            reconnectAttempt: 1,
            currentReachability: .satisfied,
            nextReconnectAt: "2026-07-08T22:25:00Z",
            userDisconnected: false
        )

        let decoded = try JSONDecoder().decode(SSHReachabilityObserver.self, from: try JSONEncoder().encode(observer))

        XCTAssertEqual(SSHReachabilityObserver.idaAlias, "SSHNetworkReachabilityObserver")
        XCTAssertEqual(decoded, observer)
    }

    func testReachabilityObserverCapturesUserDisconnectReconnectSuppression() throws {
        let observer = SSHReachabilityObserver(
            hostId: "labbox",
            heartbeatIntervalSeconds: 30,
            heartbeatTimeoutSeconds: 10,
            heartbeatTimerActive: false,
            didFireEarlyHeartbeat: false,
            lastProbeResult: .heartbeatTimeout,
            lastSuccessAt: nil,
            failureCount: 2,
            reconnectAttempt: 0,
            currentReachability: .unsatisfied,
            nextReconnectAt: nil,
            userDisconnected: true
        )

        XCTAssertTrue(observer.userDisconnected)
        XCTAssertNil(observer.nextReconnectAt)
        XCTAssertEqual(observer.lastProbeResult.failureKind, .heartbeatTimeout)
    }

    private func row(id: String, observer: SSHReachabilityObserver) -> SSHReachabilityObserverRowFixture {
        SSHReachabilityObserverRowFixture(
            id: id,
            hostId: observer.hostId,
            heartbeatIntervalSeconds: observer.heartbeatIntervalSeconds,
            heartbeatTimeoutSeconds: observer.heartbeatTimeoutSeconds,
            heartbeatTimerActive: observer.heartbeatTimerActive,
            didFireEarlyHeartbeat: observer.didFireEarlyHeartbeat,
            lastProbeResult: observer.lastProbeResult.rawValue,
            failureKind: observer.lastProbeResult.failureKind?.rawValue,
            lastSuccessAt: observer.lastSuccessAt,
            failureCount: observer.failureCount,
            reconnectAttempt: observer.reconnectAttempt,
            currentReachability: observer.currentReachability.rawValue,
            nextReconnectAt: observer.nextReconnectAt,
            userDisconnected: observer.userDisconnected
        )
    }

    private struct SSHReachabilityObserverMatrixFixture: Codable, Equatable {
        let idaAlias: String
        let rows: [SSHReachabilityObserverRowFixture]
    }

    private struct SSHReachabilityObserverRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let heartbeatIntervalSeconds: Int
        let heartbeatTimeoutSeconds: Int
        let heartbeatTimerActive: Bool
        let didFireEarlyHeartbeat: Bool
        let lastProbeResult: String
        let failureKind: String?
        let lastSuccessAt: String?
        let failureCount: Int
        let reconnectAttempt: Int
        let currentReachability: String
        let nextReconnectAt: String?
        let userDisconnected: Bool
    }
}
