import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRemoteBridgeConnectionControllerTests: XCTestCase {
    @MainActor
    func testRemoteBridgeConnectionControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteBridgeConnectionControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/remote-bridge-connection-controller-matrix")
        )

        let actual = RemoteBridgeConnectionControllerMatrixFixture(rows: [
            row(id: "upsert-sorts-connections", initial: [connection(id: "b", hostId: "devbox")], actions: [.upsert(connection(id: "a", hostId: "labbox"))]),
            row(id: "upsert-replaces-connection", initial: [connection(id: "bridge", hostId: "devbox", lastMessageAt: nil)], actions: [.upsert(connection(id: "bridge", hostId: "devbox"))]),
            row(id: "remove-existing-then-missing", initial: [connection(id: "bridge", hostId: "devbox")], actions: [.remove("bridge"), .remove("missing")])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testUpsertPublishesConnectionsSortedByConnectionId() {
        var published: [[String]] = []
        let controller = MyVibeIslandAppKitRemoteBridgeConnectionController(
            connections: [connection(id: "b", hostId: "devbox")],
            publishConnections: { connections in
                published.append(connections.map(\.connectionId))
            }
        )

        let connections = controller.upsert(connection(id: "a", hostId: "labbox"))

        XCTAssertEqual(connections.map(\.connectionId), ["a", "b"])
        XCTAssertEqual(controller.connections.map(\.connectionId), ["a", "b"])
        XCTAssertEqual(controller.lastPublishedConnections?.map(\.connectionId), ["a", "b"])
        XCTAssertEqual(published, [["a", "b"]])
    }

    @MainActor
    func testUpsertReplacesExistingConnectionForSameId() {
        let old = connection(id: "bridge", hostId: "devbox", lastMessageAt: nil)
        let new = connection(id: "bridge", hostId: "devbox", lastMessageAt: "2026-07-09T10:05:00Z")
        let controller = MyVibeIslandAppKitRemoteBridgeConnectionController(connections: [old])

        let connections = controller.upsert(new)

        XCTAssertEqual(connections, [new])
        XCTAssertEqual(controller.connections, [new])
        XCTAssertEqual(controller.lastPublishedConnections, [new])
    }

    @MainActor
    func testRemovePublishesOnlyWhenConnectionExists() {
        var publishedCounts: [Int] = []
        let controller = MyVibeIslandAppKitRemoteBridgeConnectionController(
            connections: [connection(id: "bridge", hostId: "devbox")],
            publishConnections: { connections in
                publishedCounts.append(connections.count)
            }
        )

        let removed = controller.remove(connectionId: "bridge")
        let missing = controller.remove(connectionId: "missing")

        XCTAssertTrue(removed)
        XCTAssertFalse(missing)
        XCTAssertEqual(controller.connections, [])
        XCTAssertEqual(controller.lastPublishedConnections, [])
        XCTAssertEqual(publishedCounts, [0])
    }

    private func connection(
        id: String,
        hostId: String,
        lastMessageAt: String? = "2026-07-09T10:00:00Z"
    ) -> RemoteBridgeConnection {
        RemoteBridgeConnection(
            connectionId: id,
            hostId: hostId,
            transportKind: .udsTunnel,
            connectedAt: "2026-07-09T09:59:00Z",
            lastMessageAt: lastMessageAt,
            localTunnelProcessId: 5150,
            remoteEnvironmentToken: nil,
            heartbeatIntervalSeconds: 15,
            heartbeatTimeout: 5,
            didFireEarlyHeartbeat: false
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: [RemoteBridgeConnection],
        actions: [RemoteBridgeConnectionControllerFixtureAction]
    ) -> RemoteBridgeConnectionControllerMatrixRow {
        var events: [[RemoteBridgeConnectionSummary]] = []
        let controller = MyVibeIslandAppKitRemoteBridgeConnectionController(
            connections: initial,
            publishConnections: { events.append($0.map(RemoteBridgeConnectionSummary.init)) }
        )
        var results: [String] = []

        for action in actions {
            switch action {
            case let .upsert(connection):
                results.append("connections=" + controller.upsert(connection).map(\.connectionId).joined(separator: ","))
            case let .remove(connectionId):
                results.append("removed=\(controller.remove(connectionId: connectionId))")
            }
        }

        return RemoteBridgeConnectionControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            results: results,
            connections: controller.connections.map(RemoteBridgeConnectionSummary.init),
            lastPublishedConnections: controller.lastPublishedConnections?.map(RemoteBridgeConnectionSummary.init),
            events: events
        )
    }
}

private enum RemoteBridgeConnectionControllerFixtureAction {
    case upsert(RemoteBridgeConnection)
    case remove(String)

    var summary: String {
        switch self {
        case let .upsert(connection): "upsert:\(connection.connectionId)"
        case let .remove(connectionId): "remove:\(connectionId)"
        }
    }
}

private struct RemoteBridgeConnectionControllerMatrixFixture: Codable, Equatable {
    let rows: [RemoteBridgeConnectionControllerMatrixRow]
}

private struct RemoteBridgeConnectionControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let results: [String]
    let connections: [RemoteBridgeConnectionSummary]
    let lastPublishedConnections: [RemoteBridgeConnectionSummary]?
    let events: [[RemoteBridgeConnectionSummary]]
}

private struct RemoteBridgeConnectionSummary: Codable, Equatable {
    let connectionId: String
    let hostId: String
    let lastMessageAt: String?

    init(_ connection: RemoteBridgeConnection) {
        self.connectionId = connection.connectionId
        self.hostId = connection.hostId
        self.lastMessageAt = connection.lastMessageAt
    }
}
