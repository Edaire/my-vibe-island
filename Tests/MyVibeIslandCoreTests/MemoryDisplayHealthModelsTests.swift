import XCTest
@testable import MyVibeIslandCore

final class MemoryDisplayHealthModelsTests: XCTestCase {
    func testMemoryDisplayHealthMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MemoryDisplayHealthMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/memory-display-health-matrix")
        )

        let actual = MemoryDisplayHealthMatrixFixture(rows: [
            row(
                id: "active-display-low-memory",
                memory: MemoryFootprintSnapshot(
                    virtualBytes: 2_048,
                    residentBytes: 1_024,
                    physicalFootprintBytes: 768,
                    compressedBytes: 128,
                    reusableBytes: 64
                ),
                display: DisplaySleepSnapshot(isDisplayAsleep: false, lastWakeAt: "2026-07-09T08:00:00Z")
            ),
            row(
                id: "sleeping-display-high-memory",
                memory: MemoryFootprintMonitor.Snapshot(
                    virtualBytes: 8_192,
                    residentBytes: 4_096,
                    physicalFootprintBytes: 3_072,
                    compressedBytes: 1_024,
                    reusableBytes: 512
                ),
                display: DisplaySleepObserver.Snapshot(isDisplayAsleep: true, lastWakeAt: nil)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMemoryFootprintSnapshotRoundTripsObservedFields() throws {
        let snapshot = MemoryFootprintSnapshot(
            virtualBytes: 4_096,
            residentBytes: 2_048,
            physicalFootprintBytes: 1_536,
            compressedBytes: 512,
            reusableBytes: 256
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MemoryFootprintSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.virtualBytes, 4_096)
        XCTAssertEqual(decoded.residentBytes, 2_048)
        XCTAssertEqual(decoded.physicalFootprintBytes, 1_536)
        XCTAssertEqual(decoded.compressedBytes, 512)
        XCTAssertEqual(decoded.reusableBytes, 256)
    }

    func testMemoryFootprintMonitorExposesObservedNestedSnapshotName() throws {
        let snapshot = MemoryFootprintMonitor.Snapshot(
            virtualBytes: 8_192,
            residentBytes: 4_096,
            physicalFootprintBytes: 3_072,
            compressedBytes: 1_024,
            reusableBytes: 512
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MemoryFootprintMonitor.Snapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.physicalFootprintBytes, 3_072)
    }

    func testDisplaySleepSnapshotRoundTripsObservedState() throws {
        let snapshot = DisplaySleepSnapshot(
            isDisplayAsleep: true,
            lastWakeAt: "2026-07-08T09:30:00Z"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DisplaySleepSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertTrue(decoded.isDisplayAsleep)
        XCTAssertEqual(decoded.lastWakeAt, "2026-07-08T09:30:00Z")
    }

    func testDisplaySleepObserverExposesObservedSnapshotAndEventName() throws {
        let snapshot = DisplaySleepObserver.Snapshot(
            isDisplayAsleep: false,
            lastWakeAt: "2026-07-08T09:45:00Z"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DisplaySleepObserver.Snapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertFalse(decoded.isDisplayAsleep)
        XCTAssertEqual(DisplaySleepObserver.stateDidChangeEventName, "displaySleepStateDidChange")
    }

    private func row(
        id: String,
        memory: MemoryFootprintSnapshot,
        display: DisplaySleepSnapshot
    ) -> MemoryDisplayHealthRowFixture {
        MemoryDisplayHealthRowFixture(
            id: id,
            virtualBytes: memory.virtualBytes,
            residentBytes: memory.residentBytes,
            physicalFootprintBytes: memory.physicalFootprintBytes,
            compressedBytes: memory.compressedBytes,
            reusableBytes: memory.reusableBytes,
            isDisplayAsleep: display.isDisplayAsleep,
            lastWakeAt: display.lastWakeAt,
            displayStateDidChangeEventName: DisplaySleepObserver.stateDidChangeEventName
        )
    }

    private struct MemoryDisplayHealthMatrixFixture: Codable, Equatable {
        let rows: [MemoryDisplayHealthRowFixture]
    }

    private struct MemoryDisplayHealthRowFixture: Codable, Equatable {
        let id: String
        let virtualBytes: Int64
        let residentBytes: Int64
        let physicalFootprintBytes: Int64
        let compressedBytes: Int64
        let reusableBytes: Int64
        let isDisplayAsleep: Bool
        let lastWakeAt: String?
        let displayStateDidChangeEventName: String
    }
}
