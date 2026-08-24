import XCTest
@testable import MyVibeIslandCore

final class BlockingPolicyTests: XCTestCase {
    func testBlockingPolicyMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BlockingPolicyMatrixFixture.self,
            from: try FixtureLoader.data("runtime/blocking-policy-matrix")
        )

        let actual = BlockingPolicyMatrixFixture(rows: [
            BlockingPolicyMatrixRow(
                id: "codex-permission-blocking",
                policy: BlockingPolicy(
                    source: "codex",
                    eventName: "PermissionRequest",
                    expectsResponse: true,
                    timeoutSeconds: 3600,
                    timeoutBehavior: .failOpen,
                    directiveEncoderId: "codex.permission",
                    userVisible: true
                )
            ),
            BlockingPolicyMatrixRow(
                id: "opencode-question-blocking",
                policy: BlockingPolicy(
                    source: "opencode",
                    eventName: "Question",
                    expectsResponse: true,
                    timeoutSeconds: 1800,
                    timeoutBehavior: .explicitDeny,
                    directiveEncoderId: "opencode.question",
                    userVisible: true
                )
            ),
            BlockingPolicyMatrixRow(
                id: "generic-session-fire-and-forget",
                policy: BlockingPolicy(
                    source: "generic",
                    eventName: "SessionStart",
                    expectsResponse: false,
                    timeoutBehavior: .drop,
                    userVisible: false
                )
            ),
            BlockingPolicyMatrixRow(
                id: "background-maintenance-hidden",
                policy: BlockingPolicy(
                    source: "runtime",
                    eventName: "Maintenance",
                    expectsResponse: false,
                    timeoutSeconds: nil,
                    timeoutBehavior: .explicitAllow,
                    directiveEncoderId: nil,
                    userVisible: false
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testBlockingPolicyRoundTripsSourceSpecificTimeoutFields() throws {
        let policy = BlockingPolicy(
            source: "codex",
            eventName: "PermissionRequest",
            expectsResponse: true,
            timeoutSeconds: 3600,
            timeoutBehavior: .failOpen,
            directiveEncoderId: "codex.permission",
            userVisible: true
        )

        let decoded = try JSONDecoder().decode(BlockingPolicy.self, from: try JSONEncoder().encode(policy))

        XCTAssertEqual(decoded, policy)
    }

    func testFireAndForgetPolicyDoesNotRequireTimeoutOrDirectiveEncoder() {
        let policy = BlockingPolicy(
            source: "gemini",
            eventName: "SessionStart",
            expectsResponse: false,
            timeoutSeconds: nil,
            timeoutBehavior: .drop,
            directiveEncoderId: nil,
            userVisible: false
        )

        XCTAssertFalse(policy.expectsResponse)
        XCTAssertNil(policy.timeoutSeconds)
        XCTAssertNil(policy.directiveEncoderId)
    }

    func testTimeoutBehaviorRoundTripsAllOpenBaselineValues() throws {
        let values: [BlockingTimeoutBehavior] = [
            .failOpen,
            .explicitAllow,
            .explicitDeny,
            .drop
        ]

        let decoded = try JSONDecoder().decode([BlockingTimeoutBehavior].self, from: try JSONEncoder().encode(values))

        XCTAssertEqual(decoded, values)
    }
}

private struct BlockingPolicyMatrixFixture: Codable, Equatable {
    let rows: [BlockingPolicyMatrixRow]
}

private struct BlockingPolicyMatrixRow: Codable, Equatable {
    let id: String
    let source: String
    let eventName: String
    let expectsResponse: Bool
    let timeoutSeconds: Int?
    let timeoutBehavior: BlockingTimeoutBehavior
    let directiveEncoderId: String?
    let userVisible: Bool

    init(id: String, policy: BlockingPolicy) {
        self.id = id
        self.source = policy.source
        self.eventName = policy.eventName
        self.expectsResponse = policy.expectsResponse
        self.timeoutSeconds = policy.timeoutSeconds
        self.timeoutBehavior = policy.timeoutBehavior
        self.directiveEncoderId = policy.directiveEncoderId
        self.userVisible = policy.userVisible
    }
}
