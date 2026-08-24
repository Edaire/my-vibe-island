import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHRemoteHostControllerTests: XCTestCase {
    @MainActor
    func testSSHRemoteHostControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHRemoteHostControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-remote-host-controller-matrix")
        )

        let actual = SSHRemoteHostControllerMatrixFixture(rows: [
            row(
                id: "upsert-sorts-hosts",
                initial: [host(id: "zbox", displayName: "Z Box")],
                actions: [.upsert(host(id: "abox", displayName: "A Box"))]
            ),
            row(
                id: "upsert-replaces-host",
                initial: [host(id: "devbox", displayName: "Dev Box", sessions: ["old"])],
                actions: [.upsert(host(id: "devbox", displayName: "Dev Box", sessions: ["new"]))]
            ),
            row(
                id: "remove-existing-then-missing",
                initial: [host(id: "devbox", displayName: "Dev Box")],
                actions: [.remove("devbox"), .remove("missing")]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testUpsertPublishesRemoteHostsSortedByHostId() {
        var published: [[String]] = []
        let controller = MyVibeIslandAppKitSSHRemoteHostController(
            hosts: [host(id: "zbox", displayName: "Z Box")],
            publishHosts: { hosts in
                published.append(hosts.map(\.hostId))
            }
        )

        let hosts = controller.upsert(host(id: "abox", displayName: "A Box"))

        XCTAssertEqual(hosts.map(\.hostId), ["abox", "zbox"])
        XCTAssertEqual(controller.hosts.map(\.hostId), ["abox", "zbox"])
        XCTAssertEqual(controller.lastPublishedHosts?.map(\.hostId), ["abox", "zbox"])
        XCTAssertEqual(published, [["abox", "zbox"]])
    }

    @MainActor
    func testUpsertReplacesExistingRemoteHost() {
        let old = host(id: "devbox", displayName: "Dev Box", sessions: ["old"])
        let new = host(id: "devbox", displayName: "Dev Box", sessions: ["new"])
        let controller = MyVibeIslandAppKitSSHRemoteHostController(hosts: [old])

        let hosts = controller.upsert(new)

        XCTAssertEqual(hosts, [new])
        XCTAssertEqual(controller.hosts, [new])
        XCTAssertEqual(controller.lastPublishedHosts, [new])
    }

    @MainActor
    func testRemovePublishesOnlyWhenRemoteHostExists() {
        var publishedCounts: [Int] = []
        let controller = MyVibeIslandAppKitSSHRemoteHostController(
            hosts: [host(id: "devbox", displayName: "Dev Box")],
            publishHosts: { hosts in
                publishedCounts.append(hosts.count)
            }
        )

        let removed = controller.remove(hostId: "devbox")
        let missing = controller.remove(hostId: "missing")

        XCTAssertTrue(removed)
        XCTAssertFalse(missing)
        XCTAssertEqual(controller.hosts, [])
        XCTAssertEqual(controller.lastPublishedHosts, [])
        XCTAssertEqual(publishedCounts, [0])
    }

    private func host(
        id: String,
        displayName: String,
        sessions: [String] = []
    ) -> SSHRemoteHost {
        SSHRemoteHost(
            hostId: id,
            displayName: displayName,
            connectionState: "connected",
            activeRemoteSessions: sessions,
            lastHeartbeatAt: "2026-07-09T10:15:00Z",
            lastError: nil,
            tunnelStatus: .connected,
            deployStatus: "deployed",
            hookVersion: "1.2.3",
            reconnectAttempt: 0
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: [SSHRemoteHost],
        actions: [SSHRemoteHostControllerFixtureAction]
    ) -> SSHRemoteHostControllerMatrixRow {
        var events: [[SSHRemoteHostSummary]] = []
        let controller = MyVibeIslandAppKitSSHRemoteHostController(
            hosts: initial,
            publishHosts: { events.append($0.map(SSHRemoteHostSummary.init)) }
        )
        var results: [String] = []

        for action in actions {
            switch action {
            case let .upsert(host):
                results.append("hosts=" + controller.upsert(host).map(\.hostId).joined(separator: ","))
            case let .remove(hostId):
                results.append("removed=\(controller.remove(hostId: hostId))")
            }
        }

        return SSHRemoteHostControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            results: results,
            hosts: controller.hosts.map(SSHRemoteHostSummary.init),
            lastPublishedHosts: controller.lastPublishedHosts?.map(SSHRemoteHostSummary.init),
            events: events
        )
    }
}

private enum SSHRemoteHostControllerFixtureAction {
    case upsert(SSHRemoteHost)
    case remove(String)

    var summary: String {
        switch self {
        case let .upsert(host): "upsert:\(host.hostId)"
        case let .remove(hostId): "remove:\(hostId)"
        }
    }
}

private struct SSHRemoteHostControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHRemoteHostControllerMatrixRow]
}

private struct SSHRemoteHostControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let results: [String]
    let hosts: [SSHRemoteHostSummary]
    let lastPublishedHosts: [SSHRemoteHostSummary]?
    let events: [[SSHRemoteHostSummary]]
}

private struct SSHRemoteHostSummary: Codable, Equatable {
    let hostId: String
    let displayName: String
    let activeRemoteSessions: [String]

    init(_ host: SSHRemoteHost) {
        self.hostId = host.hostId
        self.displayName = host.displayName
        self.activeRemoteSessions = host.activeRemoteSessions
    }
}
