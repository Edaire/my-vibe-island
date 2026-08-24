import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitMemoryFootprintMonitorControllerTests: XCTestCase {
    @MainActor
    func testMemoryFootprintMonitorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MemoryFootprintMonitorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/memory-footprint-monitor-controller-matrix")
        )

        let actual = MemoryFootprintMonitorControllerMatrixFixture(rows: [
            row(
                id: "record-elevated-sample",
                initialSamples: [],
                actions: [.recordSample(sample(physicalBytes: 768))]
            ),
            row(
                id: "record-sample-error-without-samples",
                initialSamples: [],
                actions: [.recordError("sample failed")]
            ),
            row(
                id: "record-error-preserves-existing-sample",
                initialSamples: [sample(physicalBytes: 256)],
                actions: [.recordError("sample failed")]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRecordsSampleAndPublishesSummary() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitMemoryFootprintMonitorController(
            monitor: MemoryFootprintMonitorModel(
                warningThresholdBytes: 512,
                criticalThresholdBytes: 1_024
            ),
            publishSummary: { summary in
                events.append("\(summary.pressure.rawValue):\(summary.sampleCount)")
            }
        )
        let snapshot = sample(physicalBytes: 768)

        let summary = controller.record(sample: snapshot)

        XCTAssertEqual(summary.pressure, .elevated)
        XCTAssertEqual(summary.latestSnapshot, snapshot)
        XCTAssertEqual(controller.state.samples, [snapshot])
        XCTAssertNil(controller.state.lastSampleError)
        XCTAssertEqual(controller.lastSummary, summary)
        XCTAssertEqual(events, ["elevated:1"])
    }

    @MainActor
    func testControllerRecordsSampleErrorAndPublishesSummary() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitMemoryFootprintMonitorController(
            publishSummary: { summary in
                events.append("\(summary.pressure.rawValue):\(summary.lastSampleError ?? "none")")
            }
        )

        let summary = controller.recordSampleError("sample failed")

        XCTAssertEqual(summary.pressure, .unknown)
        XCTAssertEqual(summary.sampleCount, 0)
        XCTAssertEqual(controller.state.lastSampleError, "sample failed")
        XCTAssertEqual(controller.lastSummary, summary)
        XCTAssertEqual(events, ["unknown:sample failed"])
    }

    @MainActor
    func testControllerPreservesExistingSamplesWhenRecordingError() {
        let existing = sample(physicalBytes: 256)
        let controller = MyVibeIslandAppKitMemoryFootprintMonitorController(
            state: MemoryFootprintMonitorState(samples: [existing])
        )

        let summary = controller.recordSampleError("sample failed")

        XCTAssertEqual(controller.state.samples, [existing])
        XCTAssertEqual(summary.latestSnapshot, existing)
        XCTAssertEqual(summary.lastSampleError, "sample failed")
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

    @MainActor
    private func row(
        id: String,
        initialSamples: [MemoryFootprintSnapshot],
        actions: [MemoryFootprintMonitorFixtureAction]
    ) -> MemoryFootprintMonitorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitMemoryFootprintMonitorController(
            monitor: MemoryFootprintMonitorModel(
                warningThresholdBytes: 512,
                criticalThresholdBytes: 1_024
            ),
            state: MemoryFootprintMonitorState(samples: initialSamples),
            publishSummary: { summary in
                events.append(
                    "\(summary.pressure.rawValue):\(summary.sampleCount):"
                    + "\(summary.lastSampleError ?? "none")"
                )
            }
        )
        var summaries: [MemoryFootprintMonitorSummarySummary] = []

        for action in actions {
            switch action {
            case let .recordSample(snapshot):
                summaries.append(MemoryFootprintMonitorSummarySummary(controller.record(sample: snapshot)))
            case let .recordError(message):
                summaries.append(MemoryFootprintMonitorSummarySummary(controller.recordSampleError(message)))
            }
        }

        return MemoryFootprintMonitorControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            summaries: summaries,
            finalState: MemoryFootprintMonitorStateSummary(controller.state),
            lastSummary: controller.lastSummary.map(MemoryFootprintMonitorSummarySummary.init),
            events: events
        )
    }
}

private struct MemoryFootprintMonitorControllerMatrixFixture: Codable, Equatable {
    let rows: [MemoryFootprintMonitorControllerMatrixRow]
}

private struct MemoryFootprintMonitorControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let summaries: [MemoryFootprintMonitorSummarySummary]
    let finalState: MemoryFootprintMonitorStateSummary
    let lastSummary: MemoryFootprintMonitorSummarySummary?
    let events: [String]
}

private struct MemoryFootprintMonitorStateSummary: Codable, Equatable {
    let sampleCount: Int
    let lastSampleError: String?
    let latestPhysicalFootprintBytes: Int64?

    init(_ state: MemoryFootprintMonitorState) {
        self.sampleCount = state.samples.count
        self.lastSampleError = state.lastSampleError
        self.latestPhysicalFootprintBytes = state.latestSnapshot?.physicalFootprintBytes
    }
}

private struct MemoryFootprintMonitorSummarySummary: Codable, Equatable {
    let sampleCount: Int
    let lastSampleError: String?
    let pressure: String
    let latestPhysicalFootprintBytes: Int64?

    init(_ summary: MemoryFootprintMonitorSummary) {
        self.sampleCount = summary.sampleCount
        self.lastSampleError = summary.lastSampleError
        self.pressure = summary.pressure.rawValue
        self.latestPhysicalFootprintBytes = summary.latestSnapshot?.physicalFootprintBytes
    }
}

private enum MemoryFootprintMonitorFixtureAction {
    case recordSample(MemoryFootprintSnapshot)
    case recordError(String)

    var summary: String {
        switch self {
        case let .recordSample(snapshot):
            return "recordSample:\(snapshot.physicalFootprintBytes)"
        case let .recordError(message):
            return "recordError:\(message)"
        }
    }
}
