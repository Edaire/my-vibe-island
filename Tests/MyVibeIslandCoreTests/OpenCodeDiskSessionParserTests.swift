import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OpenCodeDiskSessionParserTests: XCTestCase {
    func testFixtureProjectsSessionAndMessageMetadataIntoEvents() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(
            from: try FixtureLoader.data("opencode/disk-session-with-metadata")
        )

        XCTAssertEqual(snapshot.session.directory, "/tmp/opencode-fixture")
        XCTAssertEqual(snapshot.session.title, "Fixture session")
        XCTAssertEqual(snapshot.session.parentID, "opencode-parent")
        XCTAssertEqual(snapshot.messages.first?.tokens?.input, 10)
        XCTAssertEqual(snapshot.messages.first?.tokens?.output, 20)
        XCTAssertEqual(snapshot.messages.first?.tokens?.reasoning, 3)
        XCTAssertEqual(snapshot.messages.first?.tokens?.cache?.read, 4)
        XCTAssertEqual(snapshot.messages.first?.tokens?.cache?.write, 5)
        XCTAssertEqual(snapshot.agentEvents(), [
            .sessionStarted(
                source: "opencode",
                sessionId: "/tmp/opencode-fixture",
                cwd: "/tmp/opencode-fixture"
            ),
            .teamGroupingUpdated(
                source: "opencode",
                sessionId: "/tmp/opencode-fixture",
                grouping: TeamGrouping(
                    rootSessionId: "opencode-parent",
                    childToParent: ["/tmp/opencode-fixture": "opencode-parent"]
                )
            ),
            .messageReceived(
                source: "opencode",
                sessionId: "/tmp/opencode-fixture",
                message: "assistant opencode-model error"
            ),
        ])
    }

    func testDecodesDiskSessionInfo() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "directory": "/tmp/open-code-project",
            "title": "Implement parser",
            "archivedAt": "2026-07-07T08:30:00Z",
            "parentID": "parent-session",
            "hasParentIDColumn": true
          },
          "messages": []
        }
        """.utf8))

        XCTAssertEqual(snapshot.session.directory, "/tmp/open-code-project")
        XCTAssertEqual(snapshot.session.title, "Implement parser")
        XCTAssertEqual(snapshot.session.archivedAt, Date(timeIntervalSince1970: 1_783_413_000))
        XCTAssertEqual(snapshot.session.parentID, "parent-session")
        XCTAssertEqual(snapshot.session.hasParentIDColumn, true)
        XCTAssertEqual(snapshot.messages, [])
    }

    func testDecodesMessageMetadata() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "directory": "/tmp/open-code-project"
          },
          "messages": [
            {
              "id": "msg-1",
              "sessionID": "session-1",
              "role": "assistant",
              "modelID": "opencode-model",
              "cost": 0.015,
              "tokens": {
                "input": 10,
                "output": 20,
                "reasoning": 3,
                "cache": {
                  "read": 4,
                  "write": 5
                }
              },
              "time": {
                "created": "2026-07-07T08:31:00Z",
                "completed": "2026-07-07T08:32:00Z"
              },
              "error": "provider failed"
            }
          ]
        }
        """.utf8))

        let message = try XCTUnwrap(snapshot.messages.first)
        XCTAssertEqual(message.id, "msg-1")
        XCTAssertEqual(message.sessionID, "session-1")
        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.modelID, "opencode-model")
        XCTAssertEqual(message.cost, 0.015)
        XCTAssertEqual(message.tokens?.input, 10)
        XCTAssertEqual(message.tokens?.output, 20)
        XCTAssertEqual(message.tokens?.reasoning, 3)
        XCTAssertEqual(message.tokens?.cache?.read, 4)
        XCTAssertEqual(message.tokens?.cache?.write, 5)
        XCTAssertEqual(message.time?.created, Date(timeIntervalSince1970: 1_783_413_060))
        XCTAssertEqual(message.time?.completed, Date(timeIntervalSince1970: 1_783_413_120))
        XCTAssertEqual(message.error, "provider failed")
    }

    func testProjectsSessionInfoIntoEvents() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "directory": "/tmp/open-code-project",
            "title": "Implement parser",
            "parentID": "parent-session",
            "hasParentIDColumn": true
          },
          "messages": []
        }
        """.utf8))

        XCTAssertEqual(snapshot.agentEvents(), [
            .sessionStarted(
                source: "opencode",
                sessionId: "/tmp/open-code-project",
                cwd: "/tmp/open-code-project"
            ),
            .teamGroupingUpdated(
                source: "opencode",
                sessionId: "/tmp/open-code-project",
                grouping: TeamGrouping(
                    rootSessionId: "parent-session",
                    childToParent: ["/tmp/open-code-project": "parent-session"]
                )
            ),
        ])
    }

    func testProjectsMessageMetadataIntoRedactedEvents() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "directory": "/tmp/open-code-project"
          },
          "messages": [
            {
              "id": "msg-1",
              "sessionID": "session-1",
              "role": "assistant",
              "modelID": "opencode-model",
              "error": "provider failed with secret details"
            }
          ]
        }
        """.utf8))

        XCTAssertEqual(snapshot.agentEvents(), [
            .sessionStarted(
                source: "opencode",
                sessionId: "/tmp/open-code-project",
                cwd: "/tmp/open-code-project"
            ),
            .messageReceived(
                source: "opencode",
                sessionId: "session-1",
                message: "assistant opencode-model error"
            ),
        ])
    }

    func testDecodesNumericMetadataFromStrings() throws {
        let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "directory": "/tmp/open-code-project"
          },
          "messages": [
            {
              "id": "msg-1",
              "sessionID": "session-1",
              "cost": "0.015",
              "tokens": {
                "input": "10",
                "output": "20",
                "reasoning": "3",
                "cache": {
                  "read": "4",
                  "write": "5"
                }
              }
            }
          ]
        }
        """.utf8))

        let message = try XCTUnwrap(snapshot.messages.first)
        XCTAssertEqual(message.cost, 0.015)
        XCTAssertEqual(message.tokens?.input, 10)
        XCTAssertEqual(message.tokens?.output, 20)
        XCTAssertEqual(message.tokens?.reasoning, 3)
        XCTAssertEqual(message.tokens?.cache?.read, 4)
        XCTAssertEqual(message.tokens?.cache?.write, 5)
    }

    func testRejectsMissingRequiredFields() {
        XCTAssertThrowsError(try OpenCodeDiskSessionParser.parseSnapshot(from: Data("""
        {
          "session": {
            "title": "Missing directory"
          },
          "messages": [
            {
              "id": "msg-1"
            }
          ]
        }
        """.utf8)))
    }
}
