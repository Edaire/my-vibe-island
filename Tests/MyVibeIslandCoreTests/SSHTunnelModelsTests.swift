import XCTest
@testable import MyVibeIslandCore

final class SSHTunnelModelsTests: XCTestCase {
    func testSSHTunnelModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHTunnelModelMatrixFixture.self,
            from: try FixtureLoader.data("remote/ssh-tunnel-model-matrix")
        )

        let actual = SSHTunnelModelMatrixFixture(
            tunnelKinds: ([SSHTunnelKind.uds, .tcp] as [SSHTunnelKind]).map(\.rawValue),
            tunnelStatuses: ([
                .notDeployed,
                .disconnected,
                .connecting,
                .connected,
                .connectedAgo,
                .reconnecting,
                .error,
            ] as [TunnelStatus]).map(\.rawValue),
            failureKinds: ([
                .hostUnreachable,
                .authenticationFailed,
                .deployMissing,
                .hookOutdated,
                .portConflict,
                .staleListener,
                .foreignListener,
                .heartbeatTimeout,
                .commandFailed,
                .unknown,
            ] as [SSHTunnelFailureKind]).map(\.rawValue)
        )

        XCTAssertEqual(actual, expected)
    }

    func testTunnelKindUsesObservedTransportValues() throws {
        XCTAssertEqual(try JSONDecoder().decode(SSHTunnelKind.self, from: Data(#""uds""#.utf8)), .uds)
        XCTAssertEqual(try JSONDecoder().decode(SSHTunnelKind.self, from: Data(#""tcp""#.utf8)), .tcp)
        XCTAssertEqual(String(data: try JSONEncoder().encode(SSHTunnelKind.uds), encoding: .utf8), #""uds""#)
    }

    func testTunnelStatusRoundTripsDesignValues() throws {
        let statuses: [TunnelStatus] = [
            .notDeployed,
            .disconnected,
            .connecting,
            .connected,
            .connectedAgo,
            .reconnecting,
            .error
        ]

        let decoded = try JSONDecoder().decode([TunnelStatus].self, from: try JSONEncoder().encode(statuses))

        XCTAssertEqual(decoded, statuses)
    }

    func testTunnelFailureKindRoundTripsDesignValues() throws {
        let failures: [SSHTunnelFailureKind] = [
            .hostUnreachable,
            .authenticationFailed,
            .deployMissing,
            .hookOutdated,
            .portConflict,
            .staleListener,
            .foreignListener,
            .heartbeatTimeout,
            .commandFailed,
            .unknown
        ]

        let decoded = try JSONDecoder().decode([SSHTunnelFailureKind].self, from: try JSONEncoder().encode(failures))

        XCTAssertEqual(decoded, failures)
    }

    private struct SSHTunnelModelMatrixFixture: Codable, Equatable {
        let tunnelKinds: [String]
        let tunnelStatuses: [String]
        let failureKinds: [String]
    }
}
