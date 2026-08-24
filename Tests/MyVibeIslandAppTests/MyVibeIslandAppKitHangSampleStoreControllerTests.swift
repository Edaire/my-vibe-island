import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitHangSampleStoreControllerTests: XCTestCase {
    @MainActor
    func testHangSampleStoreControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HangSampleStoreControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/hang-sample-store-controller-matrix")
        )

        let actual = HangSampleStoreControllerMatrixFixture(rows: [
            row(
                id: "single-append",
                capacity: 2,
                samples: [sample(id: "first", lag: 900)]
            ),
            row(
                id: "capacity-trims-oldest",
                capacity: 2,
                samples: [
                    sample(id: "first", lag: 900),
                    sample(id: "second", lag: 1_200),
                    sample(id: "third", lag: 1_500)
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppendsSampleAndPublishesBoundedStore() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitHangSampleStoreController(
            store: HangSampleStore(capacity: 2),
            publishStore: { store in
                events.append(store.samples.map(\.detectedAt).joined(separator: ","))
            }
        )

        let store = controller.append(sample(id: "first", lag: 900))

        XCTAssertEqual(store.samples.map(\.detectedAt), ["first"])
        XCTAssertEqual(controller.store.samples.map(\.detectedAt), ["first"])
        XCTAssertEqual(controller.lastPublishedStore, store)
        XCTAssertEqual(events, ["first"])
    }

    @MainActor
    func testControllerPreservesStoreCapacityWhenAppendingManySamples() {
        let controller = MyVibeIslandAppKitHangSampleStoreController(
            store: HangSampleStore(capacity: 2)
        )

        _ = controller.append(sample(id: "first", lag: 900))
        _ = controller.append(sample(id: "second", lag: 1_200))
        let store = controller.append(sample(id: "third", lag: 1_500))

        XCTAssertEqual(store.capacity, 2)
        XCTAssertEqual(store.samples.map(\.detectedAt), ["second", "third"])
        XCTAssertEqual(store.samples.map(\.peakLagMilliseconds), [1_200, 1_500])
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

    @MainActor
    private func row(
        id: String,
        capacity: Int,
        samples: [MainThreadHangSnapshot]
    ) -> HangSampleStoreControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitHangSampleStoreController(
            store: HangSampleStore(capacity: capacity),
            publishStore: { store in
                events.append(store.samples.map(\.detectedAt).joined(separator: ","))
            }
        )
        var stores: [HangSampleStoreSummary] = []

        for sample in samples {
            stores.append(HangSampleStoreSummary(controller.append(sample)))
        }

        return HangSampleStoreControllerMatrixRow(
            id: id,
            appendedSamples: samples.map(HangSampleSummary.init),
            stores: stores,
            finalStore: HangSampleStoreSummary(controller.store),
            lastPublishedStore: controller.lastPublishedStore.map(HangSampleStoreSummary.init),
            events: events
        )
    }
}

private struct HangSampleStoreControllerMatrixFixture: Codable, Equatable {
    let rows: [HangSampleStoreControllerMatrixRow]
}

private struct HangSampleStoreControllerMatrixRow: Codable, Equatable {
    let id: String
    let appendedSamples: [HangSampleSummary]
    let stores: [HangSampleStoreSummary]
    let finalStore: HangSampleStoreSummary
    let lastPublishedStore: HangSampleStoreSummary?
    let events: [String]
}

private struct HangSampleStoreSummary: Codable, Equatable {
    let capacity: Int
    let samples: [HangSampleSummary]

    init(_ store: HangSampleStore) {
        self.capacity = store.capacity
        self.samples = store.samples.map(HangSampleSummary.init)
    }
}

private struct HangSampleSummary: Codable, Equatable {
    let detectedAt: String
    let durationMilliseconds: Int
    let peakLagMilliseconds: Int?
    let redactedStackAvailable: Bool

    init(_ sample: MainThreadHangSnapshot) {
        self.detectedAt = sample.detectedAt
        self.durationMilliseconds = sample.durationMilliseconds
        self.peakLagMilliseconds = sample.peakLagMilliseconds
        self.redactedStackAvailable = sample.redactedStackAvailable
    }
}
