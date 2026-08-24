import XCTest
@testable import MyVibeIslandCore

final class MainThreadHangSnapshotTests: XCTestCase {
    func testMainThreadHangSnapshotMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MainThreadHangSnapshotMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/main-thread-hang-snapshot-matrix")
        )

        let actual = MainThreadHangSnapshotMatrixFixture(rows: [
            row(
                id: "active-hang-with-stack",
                snapshot: MainThreadHangSnapshot(
                    detectedAt: "2026-07-09T09:10:00Z",
                    durationMilliseconds: 1_250,
                    threadStateSummary: "main thread waiting in redacted frame",
                    recentEventCount: 7,
                    redactedStackAvailable: true,
                    recoveredAt: nil,
                    peakLagMilliseconds: 1_500
                )
            ),
            row(
                id: "recovered-hang-without-stack",
                snapshot: MainThreadHangSnapshot(
                    detectedAt: "2026-07-09T09:11:00Z",
                    durationMilliseconds: 800,
                    threadStateSummary: "main thread busy in redacted event loop",
                    recentEventCount: 3,
                    redactedStackAvailable: false,
                    recoveredAt: "2026-07-09T09:11:02Z",
                    peakLagMilliseconds: nil
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMainThreadHangSnapshotRoundTripsRedactedSummaryFields() throws {
        let snapshot = MainThreadHangSnapshot(
            detectedAt: "2026-07-08T10:00:00Z",
            durationMilliseconds: 1_250,
            threadStateSummary: "main thread waiting in redacted frame",
            recentEventCount: 7,
            redactedStackAvailable: true,
            recoveredAt: "2026-07-08T10:00:02Z",
            peakLagMilliseconds: 1_500
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MainThreadHangSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.detectedAt, "2026-07-08T10:00:00Z")
        XCTAssertEqual(decoded.durationMilliseconds, 1_250)
        XCTAssertEqual(decoded.threadStateSummary, "main thread waiting in redacted frame")
        XCTAssertEqual(decoded.recentEventCount, 7)
        XCTAssertTrue(decoded.redactedStackAvailable)
        XCTAssertEqual(decoded.recoveredAt, "2026-07-08T10:00:02Z")
        XCTAssertEqual(decoded.peakLagMilliseconds, 1_500)
    }

    private func row(
        id: String,
        snapshot: MainThreadHangSnapshot
    ) -> MainThreadHangSnapshotRowFixture {
        MainThreadHangSnapshotRowFixture(
            id: id,
            detectedAt: snapshot.detectedAt,
            durationMilliseconds: snapshot.durationMilliseconds,
            threadStateSummary: snapshot.threadStateSummary,
            recentEventCount: snapshot.recentEventCount,
            redactedStackAvailable: snapshot.redactedStackAvailable,
            recoveredAt: snapshot.recoveredAt,
            peakLagMilliseconds: snapshot.peakLagMilliseconds
        )
    }

    private struct MainThreadHangSnapshotMatrixFixture: Codable, Equatable {
        let rows: [MainThreadHangSnapshotRowFixture]
    }

    private struct MainThreadHangSnapshotRowFixture: Codable, Equatable {
        let id: String
        let detectedAt: String
        let durationMilliseconds: Int
        let threadStateSummary: String
        let recentEventCount: Int
        let redactedStackAvailable: Bool
        let recoveredAt: String?
        let peakLagMilliseconds: Int?
    }
}
