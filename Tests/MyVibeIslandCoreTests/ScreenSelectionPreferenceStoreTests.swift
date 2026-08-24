import MyVibeIslandCore
import XCTest

final class ScreenSelectionPreferenceStoreTests: XCTestCase {
    func testPreferencesRoundTrip() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenSelectionPreferenceStoreTests.\(UUID().uuidString)"))
        let store = ScreenSelectionPreferenceStore(defaults: defaults)
        let preferences = ScreenSelectionPreferences(
            mode: .manualDisplay,
            selectedScreenIdentifier: "display-2",
            switchTipDismissed: true
        )

        store.save(preferences)

        XCTAssertEqual(store.load(), preferences)
    }

    func testCorruptValuesUseSafeDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenSelectionPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set("not-a-screen-mode", forKey: "screenSelection.mode")
        defaults.set("yes", forKey: "screenSelection.switchTipDismissed")
        defaults.set(NSNumber(value: 42), forKey: "screenSelection.selectedScreenIdentifier")
        let store = ScreenSelectionPreferenceStore(defaults: defaults)

        XCTAssertEqual(store.load(), ScreenSelectionPreferences())
    }

    func testBooleanAndIntegerNSNumberTypesAreNotInterchangeable() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenSelectionPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set(NSNumber(value: 1), forKey: "screenSelection.switchTipDismissed")

        XCTAssertFalse(ScreenSelectionPreferenceStore(defaults: defaults).load().switchTipDismissed)
    }

    func testInt8NSNumberIsNotAcceptedAsBoolean() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ScreenSelectionPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set(NSNumber(value: Int8(1)), forKey: "screenSelection.switchTipDismissed")

        XCTAssertFalse(ScreenSelectionPreferenceStore(defaults: defaults).load().switchTipDismissed)
    }
}
