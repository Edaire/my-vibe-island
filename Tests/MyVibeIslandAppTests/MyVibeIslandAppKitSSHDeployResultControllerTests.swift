import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHDeployResultControllerTests: XCTestCase {
    @MainActor
    func testSSHDeployResultControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHDeployResultControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-deploy-result-controller-matrix")
        )

        let success = deployResult(success: true, message: "setup complete", deployed: true)
        let failure = deployResult(success: false, message: "setup failed", deployed: false)
        let actual = SSHDeployResultControllerMatrixFixture(rows: [
            row(id: "record-success", initialResult: nil, records: [success], clearAtEnd: false),
            row(id: "replace-with-failure-and-clear", initialResult: success, records: [failure], clearAtEnd: true)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRecordPublishesLatestDeployResult() {
        var published: [SSHDeployResult] = []
        let controller = MyVibeIslandAppKitSSHDeployResultController(
            publishResult: { result in
                published.append(result)
            }
        )
        let result = deployResult(success: true, message: "setup complete", deployed: true)

        let recorded = controller.record(result)

        XCTAssertEqual(recorded, result)
        XCTAssertEqual(controller.lastResult, result)
        XCTAssertEqual(published, [result])
        XCTAssertTrue(controller.isDeployed)
    }

    @MainActor
    func testClearRemovesLastResultWithoutPublishing() {
        var publishedCount = 0
        let controller = MyVibeIslandAppKitSSHDeployResultController(
            lastResult: deployResult(success: false, message: "setup failed", deployed: false),
            publishResult: { _ in
                publishedCount += 1
            }
        )

        controller.clear()

        XCTAssertNil(controller.lastResult)
        XCTAssertFalse(controller.isDeployed)
        XCTAssertEqual(publishedCount, 0)
    }

    private func deployResult(success: Bool, message: String, deployed: Bool) -> SSHDeployResult {
        SSHDeployResult(
            success: success,
            message: message,
            stderr: success ? nil : "setup error",
            durationMs: 240,
            usedGoBinary: true,
            hostId: "devbox",
            step: "install-hook",
            remotePath: "/tmp/my-vibe-island",
            configPath: "~/.config/my-vibe-island",
            repairCommand: success ? nil : "rerun setup",
            deployed: deployed,
            lastDeployedAt: deployed ? "2026-07-09T10:10:00Z" : nil,
            lastDeployError: success ? nil : "setup error"
        )
    }

    @MainActor
    private func row(
        id: String,
        initialResult: SSHDeployResult?,
        records: [SSHDeployResult],
        clearAtEnd: Bool
    ) -> SSHDeployResultControllerMatrixRow {
        var events: [SSHDeployResult] = []
        let controller = MyVibeIslandAppKitSSHDeployResultController(
            lastResult: initialResult,
            publishResult: { events.append($0) }
        )
        let recorded = records.map(controller.record)

        if clearAtEnd {
            controller.clear()
        }

        return SSHDeployResultControllerMatrixRow(
            id: id,
            initialResult: initialResult,
            records: records,
            recorded: recorded,
            clearAtEnd: clearAtEnd,
            finalResult: controller.lastResult,
            isDeployed: controller.isDeployed,
            events: events
        )
    }
}

private struct SSHDeployResultControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHDeployResultControllerMatrixRow]
}

private struct SSHDeployResultControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialResult: SSHDeployResult?
    let records: [SSHDeployResult]
    let recorded: [SSHDeployResult]
    let clearAtEnd: Bool
    let finalResult: SSHDeployResult?
    let isDeployed: Bool
    let events: [SSHDeployResult]
}
