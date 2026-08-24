import Foundation
import XCTest
@testable import MyVibeIslandCore

final class LocalPreferenceStoreTests: XCTestCase {
    func testTypedValuesUseDefaultsOnlyWhenKeysAreAbsent() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "LocalPreferenceStoreTests.\(UUID().uuidString)"))
        let store = LocalPreferenceStore(defaults: suite)

        XCTAssertTrue(store.bool(forKey: "enabled", default: true))
        XCTAssertEqual(store.double(forKey: "scale", default: 0.3), 0.3)
        XCTAssertNil(store.string(forKey: "selection"))

        store.set(false, forKey: "enabled")
        store.set(0.75, forKey: "scale")
        store.set("system", forKey: "selection")

        XCTAssertFalse(store.bool(forKey: "enabled", default: true))
        XCTAssertEqual(store.double(forKey: "scale", default: 0.3), 0.75)
        XCTAssertEqual(store.string(forKey: "selection"), "system")
    }
}
