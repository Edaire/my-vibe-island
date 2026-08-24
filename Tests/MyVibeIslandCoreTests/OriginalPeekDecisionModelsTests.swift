import Foundation
import MyVibeIslandCore
import XCTest

final class OriginalPeekDecisionModelsTests: XCTestCase {
    func testDecisionMatrix() {
        let notification = makeNotification()
        let cases: [(OriginalPeekDecisionIntent, OriginalPeekDecision)] = [
            (
                .peek(notification, kind: .taskComplete),
                OriginalPeekDecision(
                    accepted: true,
                    reason: "peek accepted",
                    nextState: .peek(notification, kind: .taskComplete),
                    focusSessionId: nil,
                    activeSessionId: nil,
                    expansion: .peek,
                    timerPolicy: .transient,
                    hoverPolicy: .unchanged
                )
            ),
            (
                .peek(notification, kind: .statusWarning),
                OriginalPeekDecision(
                    accepted: true,
                    reason: "peek accepted",
                    nextState: .peek(notification, kind: .statusWarning),
                    focusSessionId: nil,
                    activeSessionId: nil,
                    expansion: .peek,
                    timerPolicy: .unchanged,
                    hoverPolicy: .unchanged
                )
            ),
            (
                .collapseAutoTransient,
                OriginalPeekDecision(
                    accepted: true,
                    reason: "collapse",
                    nextState: .closed,
                    focusSessionId: nil,
                    activeSessionId: nil,
                    expansion: .none,
                    timerPolicy: .cancel,
                    hoverPolicy: .shortCooldown(0.6)
                )
            ),
        ]

        for (intent, expected) in cases {
            XCTAssertEqual(OriginalPeekDecision.resolve(intent), expected)
        }
    }

    func testDecisionModelsRoundTripCodableAndAreSendable() throws {
        let notification = makeNotification()
        let values: [OriginalPeekDecision] = [
            OriginalPeekDecision.resolve(.peek(notification, kind: .taskComplete)),
            OriginalPeekDecision.resolve(.peek(notification, kind: .statusWarning)),
            OriginalPeekDecision.resolve(.collapseAutoTransient),
        ]

        for value in values {
            XCTAssertEqual(
                try JSONDecoder().decode(
                    OriginalPeekDecision.self,
                    from: JSONEncoder().encode(value)
                ),
                value
            )
            assertSendable(value)
        }

        let intents: [OriginalPeekDecisionIntent] = [
            .peek(notification, kind: .taskComplete),
            .peek(notification, kind: .statusWarning),
            .collapseAutoTransient,
        ]
        for intent in intents {
            XCTAssertEqual(
                try JSONDecoder().decode(
                    OriginalPeekDecisionIntent.self,
                    from: JSONEncoder().encode(intent)
                ),
                intent
            )
            assertSendable(intent)
        }
    }

    func testDecisionIntentContainsOnlyEvidenceCompleteCases() throws {
        let source = try originalPeekSource(named: "OriginalPeekDecisionModels.swift")
        let intentSource = try XCTUnwrap(
            source.components(separatedBy: "public enum OriginalPeekDecisionIntent").last?
                .components(separatedBy: "public struct OriginalPeekDecision").first
        )
        let cases = intentSource
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }

        XCTAssertEqual(
            cases,
            [
                "case peek(OriginalPeekNotification, kind: OriginalPeekTransientKind)",
                "case collapseAutoTransient",
            ]
        )
        XCTAssertFalse(intentSource.contains("taskCompleteProducer"))
        XCTAssertFalse(intentSource.contains("statusWarningProducer"))
        XCTAssertFalse(intentSource.contains("pendingNotification"))
        XCTAssertFalse(intentSource.contains("dedupe"))
    }

    private func makeNotification() -> OriginalPeekNotification {
        OriginalPeekNotification(
            id: "n-1",
            title: "Done",
            detail: "Task completed",
            provider: .anthropic,
            level: .info
        )
    }

    private func originalPeekSource(named name: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime")
            .appendingPathComponent(name)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
