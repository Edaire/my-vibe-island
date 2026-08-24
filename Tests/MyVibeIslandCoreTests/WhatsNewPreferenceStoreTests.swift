import MyVibeIslandCore
import XCTest

final class WhatsNewPreferenceStoreTests: XCTestCase {
    func testStateRoundTrips() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "WhatsNewPreferenceStoreTests.\(UUID().uuidString)"))
        let store = WhatsNewPreferenceStore(defaults: defaults)
        let state = WhatsNewStoreState(
            pendingHTML: "<p>News</p>",
            pendingVersion: "2.0.0",
            pendingPreviousVersion: "1.0.0",
            lastLaunchedVersion: "2.0.0"
        )

        store.save(state)

        XCTAssertEqual(store.load(), state)
    }

    func testCorruptStateFallsBackToEmptyState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "WhatsNewPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set(Data([0xff, 0x00]), forKey: "whatsNew.state")

        XCTAssertEqual(WhatsNewPreferenceStore(defaults: defaults).load(), WhatsNewStoreState())
    }
}
