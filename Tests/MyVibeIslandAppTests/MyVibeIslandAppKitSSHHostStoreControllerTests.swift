import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHHostStoreControllerTests: XCTestCase {
    @MainActor
    func testSSHHostStoreControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHHostStoreControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-host-store-controller-matrix")
        )
        let loaded = SSHHostStore(
            hosts: [host(id: "devbox", alias: "Dev Box")],
            runtimeState: SSHHostStoreRuntimeState(
                tunnelStatuses: ["devbox": .connected],
                reconnectPolicies: ["devbox": .automaticForKnownHost]
            )
        )
        let replacement = SSHHostStore(hosts: [host(id: "new", alias: "New Box")])

        let actual = SSHHostStoreControllerMatrixFixture(rows: [
            row(id: "refresh-loads-store", initial: SSHHostStore(), loaded: loaded, action: .refresh),
            row(id: "replace-skips-loader", initial: SSHHostStore(hosts: [host(id: "old", alias: "Old Box")]), loaded: SSHHostStore(), action: .replace(replacement))
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRefreshLoadsAndPublishesHostStore() {
        let loaded = SSHHostStore(
            hosts: [host(id: "devbox", alias: "Dev Box")],
            runtimeState: SSHHostStoreRuntimeState(
                tunnelStatuses: ["devbox": .connected],
                reconnectPolicies: ["devbox": .automaticForKnownHost]
            )
        )
        var published: [SSHHostStore] = []
        let controller = MyVibeIslandAppKitSSHHostStoreController(
            loadStore: { loaded },
            publishStore: { store in
                published.append(store)
            }
        )

        let store = controller.refresh()

        XCTAssertEqual(store, loaded)
        XCTAssertEqual(controller.store, loaded)
        XCTAssertEqual(controller.lastPublishedStore, loaded)
        XCTAssertEqual(published, [loaded])
    }

    @MainActor
    func testReplacePublishesNewStoreWithoutLoading() {
        var loadCount = 0
        var publishedHostIds: [[String]] = []
        let controller = MyVibeIslandAppKitSSHHostStoreController(
            store: SSHHostStore(hosts: [host(id: "old", alias: "Old Box")]),
            loadStore: {
                loadCount += 1
                return SSHHostStore()
            },
            publishStore: { store in
                publishedHostIds.append(store.hosts.map(\.id))
            }
        )
        let replacement = SSHHostStore(hosts: [host(id: "new", alias: "New Box")])

        let store = controller.replace(with: replacement)

        XCTAssertEqual(store, replacement)
        XCTAssertEqual(controller.store, replacement)
        XCTAssertEqual(controller.lastPublishedStore, replacement)
        XCTAssertEqual(loadCount, 0)
        XCTAssertEqual(publishedHostIds, [["new"]])
    }

    private func host(id: String, alias: String) -> SSHHostStoreHost {
        SSHHostStoreHost(
            id: id,
            hostAlias: alias,
            hostName: "\(id).internal",
            user: "alice",
            port: 22,
            tunnelKind: .uds,
            deployed: true,
            trustStatus: "trusted"
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: SSHHostStore,
        loaded: SSHHostStore,
        action: SSHHostStoreControllerFixtureAction
    ) -> SSHHostStoreControllerMatrixRow {
        var loadCount = 0
        var events: [SSHHostStoreSummary] = []
        let controller = MyVibeIslandAppKitSSHHostStoreController(
            store: initial,
            loadStore: {
                loadCount += 1
                return loaded
            },
            publishStore: { events.append(SSHHostStoreSummary($0)) }
        )
        let result: SSHHostStore

        switch action {
        case .refresh: result = controller.refresh()
        case let .replace(store): result = controller.replace(with: store)
        }

        return SSHHostStoreControllerMatrixRow(
            id: id,
            action: action.summary,
            result: SSHHostStoreSummary(result),
            store: SSHHostStoreSummary(controller.store),
            lastPublishedStore: controller.lastPublishedStore.map(SSHHostStoreSummary.init),
            loadCount: loadCount,
            events: events
        )
    }
}

private enum SSHHostStoreControllerFixtureAction {
    case refresh
    case replace(SSHHostStore)

    var summary: String {
        switch self {
        case .refresh: "refresh"
        case .replace: "replace"
        }
    }
}

private struct SSHHostStoreControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHHostStoreControllerMatrixRow]
}

private struct SSHHostStoreControllerMatrixRow: Codable, Equatable {
    let id: String
    let action: String
    let result: SSHHostStoreSummary
    let store: SSHHostStoreSummary
    let lastPublishedStore: SSHHostStoreSummary?
    let loadCount: Int
    let events: [SSHHostStoreSummary]
}

private struct SSHHostStoreSummary: Codable, Equatable {
    let hostIds: [String]
    let tunnelStatuses: [String: String]
    let reconnectPolicies: [String: String]

    init(_ store: SSHHostStore) {
        self.hostIds = store.hosts.map(\.id)
        self.tunnelStatuses = store.runtimeState.tunnelStatuses.mapValues(\.rawValue)
        self.reconnectPolicies = store.runtimeState.reconnectPolicies.mapValues(\.rawValue)
    }
}
