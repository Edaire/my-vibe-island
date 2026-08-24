import XCTest
@testable import MyVibeIslandCore

final class SSHHeartbeatSnapshotTests: XCTestCase {
    func testHeartbeatSnapshotMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHHeartbeatSnapshotMatrixFixture.self,
            from: try FixtureLoader.data("remote/heartbeat-snapshot-matrix")
        )

        let actual = SSHHeartbeatSnapshotMatrixFixture(rows: [
            row(
                id: "not-started",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(hostId: "coldbox", lastProbeResult: .notStarted),
                    isSuspended: false
                )
            ),
            row(
                id: "healthy-success",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(
                        hostId: "devbox",
                        heartbeatTimerActive: true,
                        didFireEarlyHeartbeat: true,
                        lastProbeResult: .succeeded,
                        lastSuccessAt: "2026-07-09T11:00:00Z"
                    ),
                    isSuspended: false
                )
            ),
            row(
                id: "network-unsatisfied-warning",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(
                        hostId: "netbox",
                        lastProbeResult: .networkUnsatisfied,
                        failureCount: 1,
                        currentReachability: .unsatisfied
                    ),
                    isSuspended: false
                )
            ),
            row(
                id: "timeout-warning",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(
                        hostId: "timeoutbox",
                        heartbeatTimerActive: true,
                        lastProbeResult: .heartbeatTimeout,
                        lastSuccessAt: "2026-07-09T10:55:00Z",
                        failureCount: 3
                    ),
                    isSuspended: false
                )
            ),
            row(
                id: "command-failed-warning",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(
                        hostId: "cmdbox",
                        lastProbeResult: .commandFailed,
                        failureCount: 2
                    ),
                    isSuspended: false
                )
            ),
            row(
                id: "suspended-clears-failure",
                snapshot: SSHHeartbeatSnapshot(
                    observer: observer(
                        hostId: "sleepingbox",
                        lastProbeResult: .heartbeatTimeout,
                        lastSuccessAt: "2026-07-09T10:55:00Z",
                        failureCount: 4
                    ),
                    isSuspended: true
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHeartbeatSnapshotReportsSuccessfulHeartbeat() throws {
        let observer = SSHReachabilityObserver(
            hostId: "devbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: true,
            didFireEarlyHeartbeat: true,
            lastProbeResult: .succeeded,
            lastSuccessAt: "2026-07-09T11:00:00Z",
            failureCount: 0,
            currentReachability: .satisfied
        )

        let snapshot = SSHHeartbeatSnapshot(observer: observer, isSuspended: false)
        let decoded = try JSONDecoder().decode(SSHHeartbeatSnapshot.self, from: try JSONEncoder().encode(snapshot))

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertEqual(snapshot.lastHeartbeatAt, "2026-07-09T11:00:00Z")
        XCTAssertEqual(snapshot.failureKind, nil)
        XCTAssertTrue(snapshot.didFireEarlyHeartbeat)
        XCTAssertFalse(snapshot.shouldShowReconnectWarning)
    }

    func testHeartbeatSnapshotReportsTimeoutWarningAndSuspendedState() {
        let timeout = SSHReachabilityObserver(
            hostId: "devbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: true,
            lastProbeResult: .heartbeatTimeout,
            lastSuccessAt: "2026-07-09T10:55:00Z",
            failureCount: 3,
            currentReachability: .satisfied
        )
        let suspended = SSHReachabilityObserver(
            hostId: "sleepingbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: false,
            lastProbeResult: .succeeded,
            lastSuccessAt: "2026-07-09T10:55:00Z",
            failureCount: 0,
            currentReachability: .satisfied
        )

        let timeoutSnapshot = SSHHeartbeatSnapshot(observer: timeout, isSuspended: false)
        let suspendedSnapshot = SSHHeartbeatSnapshot(observer: suspended, isSuspended: true)

        XCTAssertEqual(timeoutSnapshot.status, .timeout)
        XCTAssertEqual(timeoutSnapshot.failureKind, .heartbeatTimeout)
        XCTAssertTrue(timeoutSnapshot.shouldShowReconnectWarning)
        XCTAssertEqual(suspendedSnapshot.status, .suspended)
        XCTAssertFalse(suspendedSnapshot.shouldShowReconnectWarning)
    }

    private func observer(
        hostId: String,
        heartbeatTimerActive: Bool = false,
        didFireEarlyHeartbeat: Bool = false,
        lastProbeResult: SSHReachabilityProbeResult,
        lastSuccessAt: String? = nil,
        failureCount: Int = 0,
        currentReachability: SSHReachabilityState = .satisfied
    ) -> SSHReachabilityObserver {
        SSHReachabilityObserver(
            hostId: hostId,
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            heartbeatTimerActive: heartbeatTimerActive,
            didFireEarlyHeartbeat: didFireEarlyHeartbeat,
            lastProbeResult: lastProbeResult,
            lastSuccessAt: lastSuccessAt,
            failureCount: failureCount,
            currentReachability: currentReachability
        )
    }

    private func row(id: String, snapshot: SSHHeartbeatSnapshot) -> SSHHeartbeatSnapshotRowFixture {
        SSHHeartbeatSnapshotRowFixture(
            id: id,
            hostId: snapshot.hostId,
            status: snapshot.status.rawValue,
            heartbeatIntervalSeconds: snapshot.heartbeatIntervalSeconds,
            heartbeatTimeoutSeconds: snapshot.heartbeatTimeoutSeconds,
            heartbeatTimerActive: snapshot.heartbeatTimerActive,
            didFireEarlyHeartbeat: snapshot.didFireEarlyHeartbeat,
            lastHeartbeatAt: snapshot.lastHeartbeatAt,
            failureCount: snapshot.failureCount,
            failureKind: snapshot.failureKind?.rawValue,
            shouldShowReconnectWarning: snapshot.shouldShowReconnectWarning
        )
    }

    private struct SSHHeartbeatSnapshotMatrixFixture: Codable, Equatable {
        let rows: [SSHHeartbeatSnapshotRowFixture]
    }

    private struct SSHHeartbeatSnapshotRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let status: String
        let heartbeatIntervalSeconds: Int
        let heartbeatTimeoutSeconds: Int
        let heartbeatTimerActive: Bool
        let didFireEarlyHeartbeat: Bool
        let lastHeartbeatAt: String?
        let failureCount: Int
        let failureKind: String?
        let shouldShowReconnectWarning: Bool
    }
}
