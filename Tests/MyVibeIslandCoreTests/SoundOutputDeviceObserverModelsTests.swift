import XCTest
@testable import MyVibeIslandCore

final class SoundOutputDeviceObserverModelsTests: XCTestCase {
    func testOutputDeviceObserverChangesMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OutputDeviceObserverChangeFixture.self,
            from: try FixtureLoader.data("sound/output-device-observer-changes")
        )
        let observer = SoundOutputDeviceObserver()
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )
        let renamedSpeakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Built-in Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:01:00Z"
        )
        let quieterSpeakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Built-in Speakers",
            outputVolume: 0.25,
            observedAt: "2026-07-08T08:02:00Z"
        )
        let headphones = SoundOutputDeviceSnapshot(
            id: "headphones-1",
            name: "USB Headphones",
            outputVolume: 0.4,
            observedAt: "2026-07-08T08:03:00Z"
        )

        let actual = OutputDeviceObserverChangeFixture(
            selected: observer.change(from: nil, to: speakers),
            labelChanged: observer.change(from: speakers, to: renamedSpeakers),
            volumeChanged: observer.change(from: renamedSpeakers, to: quieterSpeakers),
            deviceChanged: observer.change(from: quieterSpeakers, to: headphones),
            noDevice: observer.change(from: headphones, to: nil),
            unchanged: observer.change(from: speakers, to: speakers)
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundOutputDeviceSnapshotAndChangeRoundTrip() throws {
        let change = SoundOutputDeviceChange(
            kind: .deviceChanged,
            previous: SoundOutputDeviceSnapshot(
                id: "speaker-1",
                name: "Internal Speakers",
                outputVolume: 0.6,
                observedAt: "2026-07-08T08:00:00Z"
            ),
            current: SoundOutputDeviceSnapshot(
                id: "headphones-1",
                name: "USB Headphones",
                outputVolume: 0.4,
                observedAt: "2026-07-08T08:01:00Z"
            )
        )

        let data = try JSONEncoder().encode(change)
        let decoded = try JSONDecoder().decode(SoundOutputDeviceChange.self, from: data)

        XCTAssertEqual(decoded, change)
        XCTAssertEqual(decoded.kind, .deviceChanged)
        XCTAssertEqual(decoded.current?.name, "USB Headphones")
    }

    func testObserverClassifiesSelectedChangedLabelAndVolumeChanges() {
        let observer = SoundOutputDeviceObserver()
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )
        let renamedSpeakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Built-in Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:01:00Z"
        )
        let quieterSpeakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Built-in Speakers",
            outputVolume: 0.25,
            observedAt: "2026-07-08T08:02:00Z"
        )
        let headphones = SoundOutputDeviceSnapshot(
            id: "headphones-1",
            name: "USB Headphones",
            outputVolume: 0.4,
            observedAt: "2026-07-08T08:03:00Z"
        )

        XCTAssertEqual(observer.change(from: nil, to: speakers)?.kind, .deviceSelected)
        XCTAssertEqual(observer.change(from: speakers, to: renamedSpeakers)?.kind, .labelChanged)
        XCTAssertEqual(observer.change(from: renamedSpeakers, to: quieterSpeakers)?.kind, .volumeChanged)
        XCTAssertEqual(observer.change(from: quieterSpeakers, to: headphones)?.kind, .deviceChanged)
    }

    func testObserverReturnsNilForIdenticalSnapshots() {
        let observer = SoundOutputDeviceObserver()
        let speakers = SoundOutputDeviceSnapshot(
            id: "speaker-1",
            name: "Internal Speakers",
            outputVolume: 0.6,
            observedAt: "2026-07-08T08:00:00Z"
        )

        XCTAssertNil(observer.change(from: speakers, to: speakers))
        XCTAssertNil(observer.change(from: nil, to: nil))
    }

    private struct OutputDeviceObserverChangeFixture: Codable, Equatable {
        let selected: SoundOutputDeviceChange?
        let labelChanged: SoundOutputDeviceChange?
        let volumeChanged: SoundOutputDeviceChange?
        let deviceChanged: SoundOutputDeviceChange?
        let noDevice: SoundOutputDeviceChange?
        let unchanged: SoundOutputDeviceChange?
    }
}
