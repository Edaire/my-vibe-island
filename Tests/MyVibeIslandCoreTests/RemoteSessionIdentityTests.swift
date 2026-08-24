import XCTest
@testable import MyVibeIslandCore

final class RemoteSessionIdentityTests: XCTestCase {
    func testRemoteSessionIdentityMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteSessionIdentityMatrixFixture.self,
            from: try FixtureLoader.data("remote/session-identity-matrix")
        )

        let actual = RemoteSessionIdentityMatrixFixture(rows: [
            row(
                id: "direct-normalized",
                identity: RemoteSessionIdentity(
                    source: " codex:cli ",
                    remoteSessionId: " session:1 ",
                    hostId: " host:a "
                )
            ),
            row(
                id: "jump-remote-with-host",
                identity: RemoteSessionIdentity.fromJumpInput(JumpInput(
                    sessionId: "session-1",
                    source: "codex",
                    isSSHRemote: true,
                    remoteHostId: "host-a"
                ))
            ),
            row(
                id: "jump-local-ignored",
                identity: RemoteSessionIdentity.fromJumpInput(JumpInput(
                    sessionId: "session-1",
                    source: "codex",
                    isSSHRemote: false,
                    remoteHostId: "host-a"
                ))
            ),
            row(
                id: "jump-remote-missing-host",
                identity: RemoteSessionIdentity.fromJumpInput(JumpInput(
                    sessionId: "session-1",
                    source: "codex",
                    isSSHRemote: true
                ))
            ),
            row(
                id: "jump-remote-empty-host",
                identity: RemoteSessionIdentity.fromJumpInput(JumpInput(
                    sessionId: "session-1",
                    source: "codex",
                    isSSHRemote: true,
                    remoteHostId: ""
                ))
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteSessionIdentityKeysBySourceRemoteSessionAndHost() throws {
        let first = RemoteSessionIdentity(source: "codex", remoteSessionId: "session-1", hostId: "host-a")
        let second = RemoteSessionIdentity(source: "codex", remoteSessionId: "session-1", hostId: "host-b")
        let third = RemoteSessionIdentity(source: "opencode", remoteSessionId: "session-1", hostId: "host-a")

        let decoded = try JSONDecoder().decode(RemoteSessionIdentity.self, from: try JSONEncoder().encode(first))

        XCTAssertEqual(decoded, first)
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, third)
        XCTAssertEqual(
            [first, second, third].map(\.stableLocalSessionId),
            [
                "remote:codex:host-a:session-1",
                "remote:codex:host-b:session-1",
                "remote:opencode:host-a:session-1"
            ]
        )
    }

    func testRemoteSessionIdentityBuildsOnlyFromRemoteJumpInputWithHost() {
        let remoteInput = JumpInput(
            sessionId: "session-1",
            source: "codex",
            isSSHRemote: true,
            remoteHostId: "host-a"
        )
        let localInput = JumpInput(
            sessionId: "session-1",
            source: "codex",
            isSSHRemote: false,
            remoteHostId: "host-a"
        )
        let missingHostInput = JumpInput(
            sessionId: "session-1",
            source: "codex",
            isSSHRemote: true
        )

        XCTAssertEqual(
            RemoteSessionIdentity.fromJumpInput(remoteInput)?.stableLocalSessionId,
            "remote:codex:host-a:session-1"
        )
        XCTAssertNil(RemoteSessionIdentity.fromJumpInput(localInput))
        XCTAssertNil(RemoteSessionIdentity.fromJumpInput(missingHostInput))
    }

    private func row(id: String, identity: RemoteSessionIdentity?) -> RemoteSessionIdentityRowFixture {
        RemoteSessionIdentityRowFixture(
            id: id,
            isPresent: identity != nil,
            source: identity?.source,
            remoteSessionId: identity?.remoteSessionId,
            hostId: identity?.hostId,
            stableLocalSessionId: identity?.stableLocalSessionId
        )
    }

    private struct RemoteSessionIdentityMatrixFixture: Codable, Equatable {
        let rows: [RemoteSessionIdentityRowFixture]
    }

    private struct RemoteSessionIdentityRowFixture: Codable, Equatable {
        let id: String
        let isPresent: Bool
        let source: String?
        let remoteSessionId: String?
        let hostId: String?
        let stableLocalSessionId: String?
    }
}
