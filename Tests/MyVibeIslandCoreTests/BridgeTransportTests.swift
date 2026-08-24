import XCTest
@testable import MyVibeIslandCore

final class BridgeTransportTests: XCTestCase {
    func testBridgeTransportMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BridgeTransportMatrixFixture.self,
            from: try FixtureLoader.data("runtime/bridge-transport-matrix")
        )

        let actual = BridgeTransportMatrixFixture(rows: [
            row(id: "local-unix-domain-socket", transport: BridgeTransport(
                kind: .unixDomainSocket,
                endpoint: "/tmp/my-vibe-island.sock",
                provenance: .localDesktop
            )),
            row(id: "in-memory-test-harness", transport: BridgeTransport(
                kind: .inMemory,
                endpoint: "memory://bridge",
                provenance: .testHarness
            )),
            row(id: "remote-tcp-private-listener", transport: BridgeTransport(
                kind: .remoteTCP,
                endpoint: "127.0.0.1:49221",
                provenance: .remoteForwardedSocket,
                remoteHostId: "devbox",
                isPublicListener: false
            )),
            row(id: "remote-ssh-forward", transport: BridgeTransport(
                kind: .remoteSSHForward,
                endpoint: "localhost:49222",
                provenance: .remoteForwardedSocket,
                remoteHostId: "devbox",
                isPublicListener: false
            )),
            row(id: "explicit-public-tcp-listener", transport: BridgeTransport(
                kind: .remoteTCP,
                endpoint: "0.0.0.0:49223",
                provenance: .remoteForwardedSocket,
                remoteHostId: "shared-host",
                isPublicListener: true
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testBridgeTransportRoundTripsUnixSocketDescriptor() throws {
        let transport = BridgeTransport(
            kind: .unixDomainSocket,
            endpoint: "/tmp/my-vibe-island.sock",
            provenance: .localDesktop,
            remoteHostId: nil,
            isPublicListener: false
        )

        let decoded = try JSONDecoder().decode(BridgeTransport.self, from: try JSONEncoder().encode(transport))

        XCTAssertEqual(decoded, transport)
    }

    func testBridgeTransportKindsCoverOpenBaselineVariants() throws {
        let kinds: [BridgeTransportKind] = [
            .unixDomainSocket,
            .inMemory,
            .remoteTCP,
            .remoteSSHForward
        ]

        let decoded = try JSONDecoder().decode([BridgeTransportKind].self, from: try JSONEncoder().encode(kinds))

        XCTAssertEqual(decoded, kinds)
    }

    func testRemoteTransportDescriptorKeepsPublicListenerDisabled() {
        let transport = BridgeTransport(
            kind: .remoteSSHForward,
            endpoint: "localhost:49222",
            provenance: .remoteForwardedSocket,
            remoteHostId: "devbox",
            isPublicListener: false
        )

        XCTAssertEqual(transport.remoteHostId, "devbox")
        XCTAssertFalse(transport.isPublicListener)
    }

    private func row(id: String, transport: BridgeTransport) -> BridgeTransportRowFixture {
        BridgeTransportRowFixture(
            id: id,
            kind: transport.kind.rawValue,
            endpoint: transport.endpoint,
            provenance: transport.provenance.rawValue,
            remoteHostId: transport.remoteHostId,
            isPublicListener: transport.isPublicListener
        )
    }

    private struct BridgeTransportMatrixFixture: Codable, Equatable {
        let rows: [BridgeTransportRowFixture]
    }

    private struct BridgeTransportRowFixture: Codable, Equatable {
        let id: String
        let kind: String
        let endpoint: String
        let provenance: String
        let remoteHostId: String?
        let isPublicListener: Bool
    }
}
