import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandLaunchModeTests: XCTestCase {
    func testAppShellDefaultsToAppKitAndDryRunIsExplicit() {
        let resolver = MyVibeIslandLaunchModeResolver()

        XCTAssertEqual(resolver.resolve(arguments: []).mode, .appKit)
        XCTAssertEqual(resolver.resolve(arguments: ["--dry-run"]).mode, .dryRun)
        XCTAssertEqual(resolver.resolve(arguments: ["--dry-run"]).remainingArguments, [])
    }
}
