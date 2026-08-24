import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSoundOutputDeviceObserverControllerTests: XCTestCase {
    @MainActor
    func testSoundOutputDeviceObserverControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundOutputDeviceObserverControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/sound-output-device-observer-controller-matrix")
        )
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )

        let actual = SoundOutputDeviceObserverControllerMatrixFixture(rows: [
            row(id: "publish-first-device", initial: nil, observations: [speakers]),
            row(id: "suppress-unchanged-device", initial: speakers, observations: [speakers]),
            row(id: "publish-device-disappeared", initial: speakers, observations: [nil])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPublishesOutputDeviceChangesAndStoresCurrentSnapshot() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundOutputDeviceObserverController(
            publishChange: { change in
                events.append("\(change.kind.rawValue):\(change.current?.name ?? "none")")
            }
        )
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )

        let change = controller.observe(currentSnapshot: speakers)

        XCTAssertEqual(change?.kind, .deviceSelected)
        XCTAssertEqual(controller.currentSnapshot, speakers)
        XCTAssertEqual(controller.lastChange, change)
        XCTAssertEqual(events, ["deviceSelected:Internal Speakers"])
    }

    @MainActor
    func testControllerDoesNotPublishWhenSnapshotIsUnchanged() {
        var events: [String] = []
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )
        let controller = MyVibeIslandAppKitSoundOutputDeviceObserverController(
            currentSnapshot: speakers,
            publishChange: { change in
                events.append(change.kind.rawValue)
            }
        )

        let change = controller.observe(currentSnapshot: speakers)

        XCTAssertNil(change)
        XCTAssertEqual(controller.currentSnapshot, speakers)
        XCTAssertNil(controller.lastChange)
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testControllerPublishesNoDeviceWhenOutputDisappears() {
        var events: [String] = []
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )
        let controller = MyVibeIslandAppKitSoundOutputDeviceObserverController(
            currentSnapshot: speakers,
            publishChange: { change in
                events.append("\(change.kind.rawValue):\(change.previous?.name ?? "none")")
            }
        )

        let change = controller.observe(currentSnapshot: nil)

        XCTAssertEqual(change?.kind, .noDevice)
        XCTAssertNil(controller.currentSnapshot)
        XCTAssertEqual(controller.lastChange, change)
        XCTAssertEqual(events, ["noDevice:Internal Speakers"])
    }

    @MainActor
    func testMonitorPublishesInitialAndChangedDeviceThenStopsListener() {
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-18T00:00:00Z"
        )
        let headphones = SoundOutputDeviceSnapshot(
            id: "headphones-1",
            name: "Headphones",
            outputVolume: 0.4,
            observedAt: "2026-07-18T00:01:00Z"
        )
        var current: SoundOutputDeviceSnapshot? = speakers
        var callback: (() -> Void)?
        var stopCount = 0
        let controller = MyVibeIslandAppKitSoundOutputDeviceObserverController()
        let monitor = MyVibeIslandCoreAudioOutputDeviceMonitor(
            controller: controller,
            readSnapshot: { current },
            startListening: { handler in
                callback = handler
                return { stopCount += 1 }
            }
        )

        monitor.start()
        XCTAssertEqual(controller.currentSnapshot, speakers)
        current = headphones
        callback?()
        XCTAssertEqual(controller.currentSnapshot, headphones)
        XCTAssertEqual(controller.lastChange?.kind, .deviceChanged)

        monitor.stop()
        monitor.stop()
        XCTAssertEqual(stopCount, 1)
    }

    @MainActor
    private func row(
        id: String,
        initial: SoundOutputDeviceSnapshot?,
        observations: [SoundOutputDeviceSnapshot?]
    ) -> SoundOutputDeviceObserverControllerMatrixRow {
        var events: [SoundOutputDeviceChange] = []
        let controller = MyVibeIslandAppKitSoundOutputDeviceObserverController(
            currentSnapshot: initial,
            publishChange: { events.append($0) }
        )
        let changes = observations.map { controller.observe(currentSnapshot: $0) }

        return SoundOutputDeviceObserverControllerMatrixRow(
            id: id,
            changes: changes,
            currentSnapshot: controller.currentSnapshot,
            lastChange: controller.lastChange,
            events: events
        )
    }
}

private struct SoundOutputDeviceObserverControllerMatrixFixture: Codable, Equatable {
    let rows: [SoundOutputDeviceObserverControllerMatrixRow]
}

private struct SoundOutputDeviceObserverControllerMatrixRow: Codable, Equatable {
    let id: String
    let changes: [SoundOutputDeviceChange?]
    let currentSnapshot: SoundOutputDeviceSnapshot?
    let lastChange: SoundOutputDeviceChange?
    let events: [SoundOutputDeviceChange]
}
