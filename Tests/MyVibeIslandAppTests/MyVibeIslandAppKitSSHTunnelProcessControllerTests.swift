import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHTunnelProcessControllerTests: XCTestCase {
    @MainActor
    func testSSHTunnelProcessControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHTunnelProcessControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-tunnel-process-controller-matrix")
        )

        let actual = SSHTunnelProcessControllerMatrixFixture(rows: [
            row(id: "upsert-sorts-processes", initial: [process(pid: 2, hostId: "zbox", generation: 1)], actions: [.upsert(process(pid: 1, hostId: "abox", generation: 1))]),
            row(id: "upsert-replaces-generation", initial: [process(pid: 1, hostId: "devbox", generation: 3, status: .connecting)], actions: [.upsert(process(pid: 2, hostId: "devbox", generation: 3))]),
            row(id: "remove-existing-then-missing", initial: [process(pid: 1, hostId: "devbox", generation: 1)], actions: [.remove("devbox", 1), .remove("devbox", 2)])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testUpsertPublishesTunnelProcessesSortedByHostIdAndGeneration() {
        var published: [[Int]] = []
        let controller = MyVibeIslandAppKitSSHTunnelProcessController(
            processes: [process(pid: 2, hostId: "zbox", generation: 1)],
            publishProcesses: { processes in
                published.append(processes.map(\.processId))
            }
        )

        let processes = controller.upsert(process(pid: 1, hostId: "abox", generation: 1))

        XCTAssertEqual(processes.map(\.processId), [1, 2])
        XCTAssertEqual(controller.processes.map(\.processId), [1, 2])
        XCTAssertEqual(controller.lastPublishedProcesses?.map(\.processId), [1, 2])
        XCTAssertEqual(published, [[1, 2]])
    }

    @MainActor
    func testUpsertReplacesProcessForSameHostAndGeneration() {
        let old = process(pid: 1, hostId: "devbox", generation: 3, status: .connecting)
        let new = process(pid: 2, hostId: "devbox", generation: 3, status: .connected)
        let controller = MyVibeIslandAppKitSSHTunnelProcessController(processes: [old])

        let processes = controller.upsert(new)

        XCTAssertEqual(processes, [new])
        XCTAssertEqual(controller.processes, [new])
        XCTAssertEqual(controller.lastPublishedProcesses, [new])
    }

    @MainActor
    func testRemovePublishesOnlyWhenProcessExists() {
        var publishedCounts: [Int] = []
        let controller = MyVibeIslandAppKitSSHTunnelProcessController(
            processes: [process(pid: 1, hostId: "devbox", generation: 1)],
            publishProcesses: { processes in
                publishedCounts.append(processes.count)
            }
        )

        let removed = controller.remove(hostId: "devbox", generation: 1)
        let missing = controller.remove(hostId: "devbox", generation: 2)

        XCTAssertTrue(removed)
        XCTAssertFalse(missing)
        XCTAssertEqual(controller.processes, [])
        XCTAssertEqual(controller.lastPublishedProcesses, [])
        XCTAssertEqual(publishedCounts, [0])
    }

    private func process(
        pid: Int,
        hostId: String,
        generation: Int,
        status: TunnelStatus = .connected
    ) -> SSHTunnelProcess {
        SSHTunnelProcess(
            processId: pid,
            hostId: hostId,
            tunnelKind: .uds,
            localSocketPath: "/tmp/local-\(hostId).sock",
            remoteSocketPath: "/tmp/remote-\(hostId).sock",
            startedAt: "2026-07-09T10:20:00Z",
            lastStatus: status,
            generation: generation,
            controlPath: "~/.ssh/control-\(hostId)",
            isPiggybackMode: false
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: [SSHTunnelProcess],
        actions: [SSHTunnelProcessControllerFixtureAction]
    ) -> SSHTunnelProcessControllerMatrixRow {
        var events: [[SSHTunnelProcessSummary]] = []
        let controller = MyVibeIslandAppKitSSHTunnelProcessController(
            processes: initial,
            publishProcesses: { events.append($0.map(SSHTunnelProcessSummary.init)) }
        )
        var results: [String] = []

        for action in actions {
            switch action {
            case let .upsert(process):
                results.append("pids=" + controller.upsert(process).map { String($0.processId) }.joined(separator: ","))
            case let .remove(hostId, generation):
                results.append("removed=\(controller.remove(hostId: hostId, generation: generation))")
            }
        }

        return SSHTunnelProcessControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            results: results,
            processes: controller.processes.map(SSHTunnelProcessSummary.init),
            lastPublishedProcesses: controller.lastPublishedProcesses?.map(SSHTunnelProcessSummary.init),
            events: events
        )
    }
}

private enum SSHTunnelProcessControllerFixtureAction {
    case upsert(SSHTunnelProcess)
    case remove(String, Int)

    var summary: String {
        switch self {
        case let .upsert(process): "upsert:\(process.hostId):\(process.generation)"
        case let .remove(hostId, generation): "remove:\(hostId):\(generation)"
        }
    }
}

private struct SSHTunnelProcessControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHTunnelProcessControllerMatrixRow]
}

private struct SSHTunnelProcessControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let results: [String]
    let processes: [SSHTunnelProcessSummary]
    let lastPublishedProcesses: [SSHTunnelProcessSummary]?
    let events: [[SSHTunnelProcessSummary]]
}

private struct SSHTunnelProcessSummary: Codable, Equatable {
    let processId: Int
    let hostId: String
    let generation: Int
    let status: String

    init(_ process: SSHTunnelProcess) {
        self.processId = process.processId
        self.hostId = process.hostId
        self.generation = process.generation
        self.status = process.lastStatus.rawValue
    }
}
