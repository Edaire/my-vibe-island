import XCTest
@testable import MyVibeIslandCore

final class SourceDirectiveEncoderTests: XCTestCase {
    func testSourceDirectiveEncoderMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SourceDirectiveEncoderMatrixFixture.self,
            from: try FixtureLoader.data("runtime/source-directive-encoder-matrix")
        )

        let actual = SourceDirectiveEncoderMatrixFixture(rows: [
            SourceDirectiveEncoderMatrixRow(
                id: "codex-permission-approve",
                request: permissionRequest(source: "codex"),
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
            ),
            SourceDirectiveEncoderMatrixRow(
                id: "codex-permission-deny",
                request: permissionRequest(source: "codex"),
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny)
            ),
            SourceDirectiveEncoderMatrixRow(
                id: "claude-permission-approve",
                request: permissionRequest(source: "claude"),
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
            ),
            SourceDirectiveEncoderMatrixRow(
                id: "opencode-question-answer",
                request: questionRequest(source: "opencode"),
                resolution: ActionResolution(requestId: "q1", sessionId: "s1", kind: .answer, selection: "Use option A")
            ),
            SourceDirectiveEncoderMatrixRow(
                id: "opencode-question-empty-answer",
                request: questionRequest(source: "opencode"),
                resolution: ActionResolution(requestId: "q1", sessionId: "s1", kind: .answer, selection: "")
            ),
            SourceDirectiveEncoderMatrixRow(
                id: "unknown-permission-approve",
                request: permissionRequest(source: "unknown-agent"),
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexPermissionApproveEncodesPermissionRequestAllowDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "codex"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ])))
    }

    func testCodexPermissionDenyEncodesPermissionRequestDenyDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "codex"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("deny"),
                    "message": .string("Permission denied in My Vibe Island."),
                ]),
            ]),
        ])))
    }

    func testClaudeCompatiblePermissionApproveEncodesPermissionRequestAllowDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "claude"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "suppressOutput": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([:]),
                    "updatedPermissions": .array([]),
                ]),
            ]),
        ])))
    }

    func testClaudeCompatiblePermissionDenyEncodesPermissionRequestDenyDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "claude"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "suppressOutput": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("deny"),
                    "message": .string("User denied the permission request"),
                    "interrupt": .bool(false),
                ]),
            ]),
        ])))
    }

    func testOpenCodePermissionApproveEncodesAllowDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "opencode"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ])))
    }

    func testOpenCodePermissionDenyEncodesDenyDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "opencode"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny)
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("deny"),
                    "reason": .string("Permission denied in My Vibe Island."),
                ]),
            ]),
        ])))
    }

    func testOpenCodePermissionAlwaysAllowUsesRecoveredHookDecisionEnvelope() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "opencode"),
            resolution: ActionResolution(
                requestId: "r1",
                sessionId: "s1",
                kind: .approveAlways
            )
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("always"),
                ]),
            ]),
        ])))
    }

    func testOpenCodeQuestionAnswerEncodesAnswerDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: questionRequest(source: "opencode"),
            resolution: ActionResolution(requestId: "q1", sessionId: "s1", kind: .answer, selection: "Use option A")
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([
                        "answers": .object([
                            "Question": .string("Use option A"),
                        ]),
                    ]),
                ]),
            ]),
        ])))
    }

    func testOpenCodeMultiQuestionAnswerUsesRecoveredHeaderAnswerMap() {
        let directive = AgentAdapterRegistry.default.directive(
            for: questionRequest(source: "opencode"),
            resolution: ActionResolution(
                requestId: "q1",
                sessionId: "s1",
                kind: .answer,
                answers: [
                    "Target": "Local",
                    "Checks": "Tests, Lint",
                ]
            )
        )

        XCTAssertEqual(directive, .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([
                        "answers": .object([
                            "Target": .string("Local"),
                            "Checks": .string("Tests, Lint"),
                        ]),
                    ]),
                ]),
            ]),
        ])))
    }

    func testUnknownSourceReturnsNoDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "unknown-agent"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)
        )

        XCTAssertEqual(directive, .none)
    }

    func testUnsupportedResolutionKindReturnsNoDirective() {
        let directive = AgentAdapterRegistry.default.directive(
            for: permissionRequest(source: "codex"),
            resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .answer, selection: "yes")
        )

        XCTAssertEqual(directive, .none)
    }

    func testRegistryReturnsCodexPermissionBlockingTimeout() {
        XCTAssertEqual(
            AgentAdapterRegistry.default.blockingTimeout(for: permissionRequest(source: "codex")),
            7_200
        )
    }

    func testRegistryReturnsClaudeCompatiblePermissionBlockingTimeout() {
        XCTAssertEqual(
            AgentAdapterRegistry.default.blockingTimeout(for: permissionRequest(source: "claude")),
            86_400
        )
    }

    func testRegistryReturnsOpenCodePermissionAndQuestionBlockingTimeout() {
        XCTAssertEqual(
            AgentAdapterRegistry.default.blockingTimeout(for: permissionRequest(source: "opencode")),
            3_600
        )
        XCTAssertEqual(
            AgentAdapterRegistry.default.blockingTimeout(for: questionRequest(source: "opencode")),
            3_600
        )
    }

    func testRegistryReturnsNoBlockingTimeoutForUnknownSource() {
        XCTAssertNil(AgentAdapterRegistry.default.blockingTimeout(for: permissionRequest(source: "unknown-agent")))
    }

    private func permissionRequest(source: String) -> ActionableRequest {
        ActionableRequest(
            requestId: "r1",
            sessionId: "s1",
            source: source,
            kind: .permission,
            toolName: "Shell"
        )
    }

    private func questionRequest(source: String) -> ActionableRequest {
        ActionableRequest(
            requestId: "q1",
            sessionId: "s1",
            source: source,
            kind: .question,
            toolName: "Question"
        )
    }
}

private struct SourceDirectiveEncoderMatrixFixture: Codable, Equatable {
    let rows: [SourceDirectiveEncoderMatrixRow]
}

private struct SourceDirectiveEncoderMatrixRow: Codable, Equatable {
    let id: String
    let source: String
    let requestKind: ActionableRequestKind
    let resolutionKind: ActionResolutionKind
    let directiveKind: String
    let directiveType: String?
    let decisionBehavior: String?
    let answerText: String?
    let blockingTimeoutSeconds: Int?

    init(id: String, request: ActionableRequest, resolution: ActionResolution) {
        let registry = AgentAdapterRegistry.default
        let directive = registry.directive(for: request, resolution: resolution)

        self.id = id
        self.source = request.source
        self.requestKind = request.kind
        self.resolutionKind = resolution.kind
        self.directiveKind = directive.kindName
        self.directiveType = directive.jsonValue?.objectString("type")
        self.decisionBehavior = directive.jsonValue?.hookDecisionBehavior
        self.answerText = directive.jsonValue?.objectString("text")
        self.blockingTimeoutSeconds = registry.blockingTimeout(for: request).map(Int.init)
    }
}

private extension SourceDirective {
    var kindName: String {
        switch self {
        case .none:
            return "none"
        case .json:
            return "json"
        }
    }

    var jsonValue: BridgeJSONValue? {
        switch self {
        case .none:
            return nil
        case let .json(value):
            return value
        }
    }
}

private extension BridgeJSONValue {
    func objectString(_ key: String) -> String? {
        guard case let .object(object) = self, case let .string(value)? = object[key] else {
            return nil
        }

        return value
    }

    var hookDecisionBehavior: String? {
        guard
            case let .object(root) = self,
            case let .object(output)? = root["hookSpecificOutput"],
            case let .object(decision)? = output["decision"],
            case let .string(behavior)? = decision["behavior"]
        else {
            return nil
        }

        return behavior
    }
}
