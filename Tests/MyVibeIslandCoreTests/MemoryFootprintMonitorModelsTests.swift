import XCTest
@testable import MyVibeIslandCore

final class MemoryFootprintMonitorModelsTests: XCTestCase {
    func testMemoryFootprintMonitorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MemoryFootprintMonitorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/memory-footprint-monitor-matrix")
        )

        let actual = MemoryFootprintMonitorMatrixFixture(rows: [
            row(
                id: "unknown-with-error",
                monitor: MemoryFootprintMonitorModel(warningThresholdBytes: 512, criticalThresholdBytes: 1_024),
                state: MemoryFootprintMonitorState(samples: [], lastSampleError: "sample failed")
            ),
            row(
                id: "normal-latest-sample",
                monitor: MemoryFootprintMonitorModel(warningThresholdBytes: 512, criticalThresholdBytes: 1_024),
                state: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 256)])
            ),
            row(
                id: "elevated-latest-sample",
                monitor: MemoryFootprintMonitorModel(warningThresholdBytes: 512, criticalThresholdBytes: 1_024),
                state: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 256), sample(physicalBytes: 768)])
            ),
            row(
                id: "critical-latest-sample",
                monitor: MemoryFootprintMonitorModel(warningThresholdBytes: 512, criticalThresholdBytes: 1_024),
                state: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 1_500)])
            ),
            row(
                id: "critical-threshold-clamped-to-warning",
                monitor: MemoryFootprintMonitorModel(warningThresholdBytes: 1_024, criticalThresholdBytes: 512),
                state: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 1_024)])
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMemoryFootprintMonitorStateRoundTripsSamplesAndLastError() throws {
        let state = MemoryFootprintMonitorState(
            samples: [sample(physicalBytes: 256), sample(physicalBytes: 768)],
            lastSampleError: "sample failed"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MemoryFootprintMonitorState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.latestSnapshot?.physicalFootprintBytes, 768)
        XCTAssertEqual(decoded.lastSampleError, "sample failed")
    }

    func testMemoryFootprintMonitorSummarizesPressureFromLatestSample() {
        let monitor = MemoryFootprintMonitorModel(
            warningThresholdBytes: 512,
            criticalThresholdBytes: 1_024
        )

        XCTAssertEqual(monitor.summary(for: MemoryFootprintMonitorState()).pressure, .unknown)
        XCTAssertEqual(
            monitor.summary(for: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 256)])).pressure,
            .normal
        )
        XCTAssertEqual(
            monitor.summary(for: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 768)])).pressure,
            .elevated
        )
        XCTAssertEqual(
            monitor.summary(for: MemoryFootprintMonitorState(samples: [sample(physicalBytes: 1_500)])).pressure,
            .critical
        )
    }

    private func sample(physicalBytes: Int64) -> MemoryFootprintSnapshot {
        MemoryFootprintSnapshot(
            virtualBytes: physicalBytes * 2,
            residentBytes: physicalBytes,
            physicalFootprintBytes: physicalBytes,
            compressedBytes: 0,
            reusableBytes: 0
        )
    }

    private func row(
        id: String,
        monitor: MemoryFootprintMonitorModel,
        state: MemoryFootprintMonitorState
    ) -> MemoryFootprintMonitorRowFixture {
        let summary = monitor.summary(for: state)

        return MemoryFootprintMonitorRowFixture(
            id: id,
            warningThresholdBytes: monitor.warningThresholdBytes,
            criticalThresholdBytes: monitor.criticalThresholdBytes,
            sampleCount: summary.sampleCount,
            latestPhysicalFootprintBytes: summary.latestSnapshot?.physicalFootprintBytes,
            latestVirtualBytes: summary.latestSnapshot?.virtualBytes,
            latestResidentBytes: summary.latestSnapshot?.residentBytes,
            lastSampleError: summary.lastSampleError,
            pressure: summary.pressure.rawValue
        )
    }

    private struct MemoryFootprintMonitorMatrixFixture: Codable, Equatable {
        let rows: [MemoryFootprintMonitorRowFixture]
    }

    private struct MemoryFootprintMonitorRowFixture: Codable, Equatable {
        let id: String
        let warningThresholdBytes: Int64
        let criticalThresholdBytes: Int64
        let sampleCount: Int
        let latestPhysicalFootprintBytes: Int64?
        let latestVirtualBytes: Int64?
        let latestResidentBytes: Int64?
        let lastSampleError: String?
        let pressure: String
    }
}
