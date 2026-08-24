import XCTest
@testable import MyVibeIslandCore

final class HangSampleStoreModelsTests: XCTestCase {
    func testHangSampleStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HangSampleStoreMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/hang-sample-store-matrix")
        )

        var appended = HangSampleStore(capacity: 2)
        appended.append(sample(id: "first", lag: 900))
        appended.append(sample(id: "second", lag: 1_200))
        appended.append(sample(id: "third", lag: 1_500))

        var clamped = HangSampleStore(capacity: 0)
        clamped.append(sample(id: "only", lag: 700))
        clamped.append(sample(id: "latest", lag: 800))

        let initialized = HangSampleStore(
            capacity: 2,
            samples: [
                sample(id: "old", lag: 500),
                sample(id: "middle", lag: 600),
                sample(id: "new", lag: 700),
            ]
        )

        let actual = HangSampleStoreMatrixFixture(rows: [
            row(id: "append-keeps-most-recent", store: appended),
            row(id: "capacity-clamped-to-one", store: clamped),
            row(id: "initializer-keeps-suffix", store: initialized),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHangSampleStoreKeepsMostRecentSamplesWithinCapacity() {
        var store = HangSampleStore(capacity: 2)

        store.append(sample(id: "first", lag: 900))
        store.append(sample(id: "second", lag: 1_200))
        store.append(sample(id: "third", lag: 1_500))

        XCTAssertEqual(store.capacity, 2)
        XCTAssertEqual(store.samples.map(\.detectedAt), ["second", "third"])
        XCTAssertEqual(store.samples.map(\.peakLagMilliseconds), [1_200, 1_500])
    }

    func testHangSampleStoreCapacityIsAtLeastOneAndRoundTrips() throws {
        var store = HangSampleStore(capacity: 0)
        store.append(sample(id: "only", lag: 700))
        store.append(sample(id: "latest", lag: 800))

        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(HangSampleStore.self, from: data)

        XCTAssertEqual(decoded.capacity, 1)
        XCTAssertEqual(decoded.samples.map(\.detectedAt), ["latest"])
    }

    private func sample(id: String, lag: Int) -> MainThreadHangSnapshot {
        MainThreadHangSnapshot(
            detectedAt: id,
            durationMilliseconds: lag,
            threadStateSummary: "redacted wait",
            recentEventCount: 3,
            redactedStackAvailable: true,
            peakLagMilliseconds: lag
        )
    }

    private func row(id: String, store: HangSampleStore) -> HangSampleStoreRowFixture {
        HangSampleStoreRowFixture(
            id: id,
            capacity: store.capacity,
            sampleCount: store.samples.count,
            detectedAtValues: store.samples.map(\.detectedAt),
            peakLagMilliseconds: store.samples.map { $0.peakLagMilliseconds ?? $0.durationMilliseconds },
            redactedStackAvailableValues: store.samples.map(\.redactedStackAvailable),
            recoveredAtValues: store.samples.map(\.recoveredAt)
        )
    }

    private struct HangSampleStoreMatrixFixture: Codable, Equatable {
        let rows: [HangSampleStoreRowFixture]
    }

    private struct HangSampleStoreRowFixture: Codable, Equatable {
        let id: String
        let capacity: Int
        let sampleCount: Int
        let detectedAtValues: [String]
        let peakLagMilliseconds: [Int]
        let redactedStackAvailableValues: [Bool]
        let recoveredAtValues: [String?]
    }
}
