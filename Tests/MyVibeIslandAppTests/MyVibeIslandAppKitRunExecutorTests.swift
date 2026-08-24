import AppKit
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRunExecutorTests: XCTestCase {
    @MainActor
    func testRunExecutorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RunExecutorMatrixFixture.self,
            from: try AppFixtureLoader.data("app/run-executor-matrix")
        )

        let actual = RunExecutorMatrixFixture(rows: [
            row(
                id: "full-launch",
                intents: [
                    .setActivationPolicy(.accessory),
                    .installDelegate,
                    .runApplication
                ]
            ),
            row(
                id: "platform-preflight-only",
                intents: [
                    .setActivationPolicy(.regular),
                    .installDelegate
                ]
            ),
            row(
                id: "policy-only",
                intents: [
                    .setActivationPolicy(.prohibited)
                ]
            ),
            row(
                id: "empty-plan",
                intents: []
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testExecutorAppliesActivationPolicyAndInstallsDelegateInOrder() {
        let delegate = MyVibeIslandAppKitDelegate()
        var events: [String] = []
        let executor = MyVibeIslandAppKitRunExecutor(
            setActivationPolicy: { policy in
                events.append("policy:\(policy.rawValue)")
            },
            installDelegate: { installed in
                XCTAssertTrue(installed === delegate)
                events.append("delegate")
            },
            runApplication: {
                events.append("run")
            }
        )

        executor.execute(
            MyVibeIslandAppKitRunPlan(
                delegate: delegate,
                intents: [
                    .setActivationPolicy(.accessory),
                    .installDelegate,
                    .runApplication
                ]
            )
        )

        XCTAssertEqual(events, [
            "policy:accessory",
            "delegate",
            "run"
        ])
    }

    @MainActor
    private func row(
        id: String,
        intents: [MyVibeIslandAppKitRunIntent]
    ) -> RunExecutorMatrixRow {
        let delegate = MyVibeIslandAppKitDelegate()
        var events: [String] = []
        let executor = MyVibeIslandAppKitRunExecutor(
            setActivationPolicy: { policy in
                events.append("policy:\(policy.rawValue)")
            },
            installDelegate: { installed in
                events.append(installed === delegate ? "delegate:expected" : "delegate:unexpected")
            },
            runApplication: {
                events.append("run")
            }
        )

        executor.execute(
            MyVibeIslandAppKitRunPlan(
                delegate: delegate,
                intents: intents
            )
        )

        return RunExecutorMatrixRow(
            id: id,
            intents: intents.map(\.summary),
            events: events
        )
    }
}

private struct RunExecutorMatrixFixture: Codable, Equatable {
    let rows: [RunExecutorMatrixRow]
}

private struct RunExecutorMatrixRow: Codable, Equatable {
    let id: String
    let intents: [String]
    let events: [String]
}

private extension MyVibeIslandAppKitRunIntent {
    var summary: String {
        switch self {
        case let .setActivationPolicy(policy):
            return "setActivationPolicy:\(policy.rawValue)"
        case .installDelegate:
            return "installDelegate"
        case .runApplication:
            return "runApplication"
        }
    }
}
