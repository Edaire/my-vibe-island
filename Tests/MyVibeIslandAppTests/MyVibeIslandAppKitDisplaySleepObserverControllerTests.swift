import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDisplaySleepObserverControllerTests: XCTestCase {
    @MainActor
    func testDisplaySleepObserverControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DisplaySleepObserverControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/display-sleep-observer-controller-matrix")
        )

        let awake = DisplaySleepSnapshot(
            isDisplayAsleep: false,
            lastWakeAt: "2026-07-08T09:45:00Z"
        )
        let asleep = DisplaySleepSnapshot(
            isDisplayAsleep: true,
            lastWakeAt: "2026-07-08T09:45:00Z"
        )

        let actual = DisplaySleepObserverControllerMatrixFixture(rows: [
            row(id: "first-observed-awake", initialSnapshot: nil, observedSnapshots: [awake]),
            row(id: "unchanged-awake", initialSnapshot: awake, observedSnapshots: [awake]),
            row(id: "awake-to-asleep", initialSnapshot: awake, observedSnapshots: [asleep])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPublishesSnapshotWhenDisplaySleepStateChanges() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDisplaySleepObserverController(
            currentSnapshot: DisplaySleepSnapshot(isDisplayAsleep: false, lastWakeAt: "2026-07-08T09:45:00Z"),
            publishStateDidChange: { snapshot in
                events.append("\(snapshot.isDisplayAsleep):\(snapshot.lastWakeAt ?? "none")")
            }
        )
        let asleep = DisplaySleepSnapshot(isDisplayAsleep: true, lastWakeAt: "2026-07-08T09:45:00Z")

        let didPublish = controller.observe(snapshot: asleep)

        XCTAssertTrue(didPublish)
        XCTAssertEqual(controller.currentSnapshot, asleep)
        XCTAssertEqual(controller.lastPublishedSnapshot, asleep)
        XCTAssertEqual(controller.eventName, DisplaySleepObserver.stateDidChangeEventName)
        XCTAssertEqual(events, ["true:2026-07-08T09:45:00Z"])
    }

    @MainActor
    func testControllerDoesNotPublishWhenSnapshotIsUnchanged() {
        var events: [String] = []
        let awake = DisplaySleepSnapshot(isDisplayAsleep: false, lastWakeAt: "2026-07-08T09:45:00Z")
        let controller = MyVibeIslandAppKitDisplaySleepObserverController(
            currentSnapshot: awake,
            publishStateDidChange: { snapshot in
                events.append("\(snapshot.isDisplayAsleep)")
            }
        )

        let didPublish = controller.observe(snapshot: awake)

        XCTAssertFalse(didPublish)
        XCTAssertEqual(controller.currentSnapshot, awake)
        XCTAssertNil(controller.lastPublishedSnapshot)
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testControllerPublishesFirstObservedSnapshot() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDisplaySleepObserverController(
            publishStateDidChange: { snapshot in
                events.append(snapshot.isDisplayAsleep ? "asleep" : "awake")
            }
        )
        let awake = DisplaySleepSnapshot(isDisplayAsleep: false, lastWakeAt: "2026-07-08T09:45:00Z")

        let didPublish = controller.observe(snapshot: awake)

        XCTAssertTrue(didPublish)
        XCTAssertEqual(controller.currentSnapshot, awake)
        XCTAssertEqual(controller.lastPublishedSnapshot, awake)
        XCTAssertEqual(events, ["awake"])
    }

    @MainActor
    private func row(
        id: String,
        initialSnapshot: DisplaySleepSnapshot?,
        observedSnapshots: [DisplaySleepSnapshot]
    ) -> DisplaySleepObserverControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDisplaySleepObserverController(
            currentSnapshot: initialSnapshot,
            publishStateDidChange: { snapshot in
                events.append("\(snapshot.isDisplayAsleep):\(snapshot.lastWakeAt ?? "none")")
            }
        )
        let results = observedSnapshots.map { controller.observe(snapshot: $0) }

        return DisplaySleepObserverControllerMatrixRow(
            id: id,
            eventName: controller.eventName,
            initialSnapshot: initialSnapshot.map(DisplaySleepSnapshotSummary.init),
            observedSnapshots: observedSnapshots.map(DisplaySleepSnapshotSummary.init),
            publishResults: results,
            currentSnapshot: controller.currentSnapshot.map(DisplaySleepSnapshotSummary.init),
            lastPublishedSnapshot: controller.lastPublishedSnapshot.map(DisplaySleepSnapshotSummary.init),
            events: events
        )
    }
}

private struct DisplaySleepObserverControllerMatrixFixture: Codable, Equatable {
    let rows: [DisplaySleepObserverControllerMatrixRow]
}

private struct DisplaySleepObserverControllerMatrixRow: Codable, Equatable {
    let id: String
    let eventName: String
    let initialSnapshot: DisplaySleepSnapshotSummary?
    let observedSnapshots: [DisplaySleepSnapshotSummary]
    let publishResults: [Bool]
    let currentSnapshot: DisplaySleepSnapshotSummary?
    let lastPublishedSnapshot: DisplaySleepSnapshotSummary?
    let events: [String]
}

private struct DisplaySleepSnapshotSummary: Codable, Equatable {
    let isDisplayAsleep: Bool
    let lastWakeAt: String?

    init(_ snapshot: DisplaySleepSnapshot) {
        self.isDisplayAsleep = snapshot.isDisplayAsleep
        self.lastWakeAt = snapshot.lastWakeAt
    }
}
