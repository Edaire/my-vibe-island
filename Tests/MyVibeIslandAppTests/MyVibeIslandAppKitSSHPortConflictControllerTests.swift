import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHPortConflictControllerTests: XCTestCase {
    @MainActor
    func testSSHPortConflictControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHPortConflictControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-port-conflict-controller-matrix")
        )
        let cleanup = conflict(decision: .sameUserStaleSSHDCleanupAllowed, sameUserSSHPids: [101])
        let unknown = conflict(decision: .unknownFailClosed)

        let actual = SSHPortConflictControllerMatrixFixture(rows: [
            row(id: "record-cleanup-allowed", initial: nil, record: cleanup, clearAtEnd: false),
            row(id: "record-unknown-fails-closed", initial: nil, record: unknown, clearAtEnd: false),
            row(id: "clear-without-publish", initial: unknown, record: nil, clearAtEnd: true)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRecordPublishesConflictAndExposesSafetyFlags() {
        var published: [SSHPortConflict] = []
        let controller = MyVibeIslandAppKitSSHPortConflictController(
            publishConflict: { conflict in
                published.append(conflict)
            }
        )
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            sameUserSSHPids: [101],
            checkedByLsof: true,
            checkedBySS: true,
            decision: .sameUserStaleSSHDCleanupAllowed
        )

        let recorded = controller.record(conflict)

        XCTAssertEqual(recorded, conflict)
        XCTAssertEqual(controller.lastConflict, conflict)
        XCTAssertTrue(controller.allowsAutomaticCleanup)
        XCTAssertFalse(controller.failsClosed)
        XCTAssertEqual(published, [conflict])
    }

    @MainActor
    func testClearRemovesConflictWithoutPublishingCleanupAction() {
        var publishCount = 0
        let controller = MyVibeIslandAppKitSSHPortConflictController(
            lastConflict: SSHPortConflict(
                hostId: "devbox",
                port: 42042,
                checkedByLsof: false,
                checkedBySS: false,
                decision: .unknownFailClosed
            ),
            publishConflict: { _ in
                publishCount += 1
            }
        )

        controller.clear()

        XCTAssertNil(controller.lastConflict)
        XCTAssertFalse(controller.allowsAutomaticCleanup)
        XCTAssertFalse(controller.failsClosed)
        XCTAssertEqual(publishCount, 0)
    }

    private func conflict(
        decision: SSHPortConflictDecision,
        sameUserSSHPids: [Int] = []
    ) -> SSHPortConflict {
        SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            sameUserSSHPids: sameUserSSHPids,
            checkedByLsof: true,
            checkedBySS: true,
            decision: decision
        )
    }

    @MainActor
    private func row(
        id: String,
        initial: SSHPortConflict?,
        record: SSHPortConflict?,
        clearAtEnd: Bool
    ) -> SSHPortConflictControllerMatrixRow {
        var events: [SSHPortConflict] = []
        let controller = MyVibeIslandAppKitSSHPortConflictController(
            lastConflict: initial,
            publishConflict: { events.append($0) }
        )

        if let record { controller.record(record) }
        if clearAtEnd { controller.clear() }

        return SSHPortConflictControllerMatrixRow(
            id: id,
            lastConflict: controller.lastConflict,
            allowsAutomaticCleanup: controller.allowsAutomaticCleanup,
            failsClosed: controller.failsClosed,
            events: events
        )
    }
}

private struct SSHPortConflictControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHPortConflictControllerMatrixRow]
}

private struct SSHPortConflictControllerMatrixRow: Codable, Equatable {
    let id: String
    let lastConflict: SSHPortConflict?
    let allowsAutomaticCleanup: Bool
    let failsClosed: Bool
    let events: [SSHPortConflict]
}
