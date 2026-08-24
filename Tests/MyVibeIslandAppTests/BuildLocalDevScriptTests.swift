import Foundation
import XCTest

final class BuildLocalDevScriptTests: XCTestCase {
    func testRunModeDoesNotForceANewAppInstance() throws {
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertFalse(script.contains("open -n \"$app\""))
        XCTAssertTrue(script.contains("open \"$app\""))
    }

    private var scriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Scripts/build-local-dev.sh")
    }
}
