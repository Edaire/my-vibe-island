import XCTest
@testable import MyVibeIslandCore

final class AppExecutableModeModelsTests: XCTestCase {
    func testAppExecutableModeMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppExecutableModeMatrixFixture.self,
            from: try FixtureLoader.data("runtime/app-executable-mode-matrix")
        )
        let resolver = AppExecutableModeResolver()

        let actual = AppExecutableModeMatrixFixture(rows: [
            AppExecutableModeMatrixRow(id: "empty-app-shell", resolution: resolver.resolve(arguments: [])),
            AppExecutableModeMatrixRow(id: "app-flag", resolution: resolver.resolve(arguments: ["--app"])),
            AppExecutableModeMatrixRow(id: "app-alias-with-remaining", resolution: resolver.resolve(arguments: ["app", "--screen", "main"])),
            AppExecutableModeMatrixRow(id: "launch-app-alias", resolution: resolver.resolve(arguments: ["launch-app"])),
            AppExecutableModeMatrixRow(id: "help-long", resolution: resolver.resolve(arguments: ["--help"])),
            AppExecutableModeMatrixRow(id: "help-short", resolution: resolver.resolve(arguments: ["-h"])),
            AppExecutableModeMatrixRow(id: "double-dash-cli", resolution: resolver.resolve(arguments: ["--", "--app", "status"])),
            AppExecutableModeMatrixRow(id: "known-status-cli", resolution: resolver.resolve(arguments: ["status"])),
            AppExecutableModeMatrixRow(id: "known-jump-cli", resolution: resolver.resolve(arguments: ["jump", "session-1"])),
            AppExecutableModeMatrixRow(id: "known-bridge-smoke-cli", resolution: resolver.resolve(arguments: ["bridge-smoke"])),
            AppExecutableModeMatrixRow(id: "unknown-word-cli", resolution: resolver.resolve(arguments: ["inspect"])),
            AppExecutableModeMatrixRow(id: "unknown-switch-invalid", resolution: resolver.resolve(arguments: ["--unknown"])),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testNoArgumentsResolveToAppShellMode() {
        let resolution = AppExecutableModeResolver().resolve(arguments: [])

        XCTAssertEqual(resolution.mode, .appShell)
        XCTAssertEqual(resolution.remainingArguments, [])
        XCTAssertNil(resolution.diagnostic)
    }

    func testAppAliasesResolveToAppShellModeAndRemoveAlias() {
        let resolver = AppExecutableModeResolver()

        XCTAssertEqual(resolver.resolve(arguments: ["--app"]).mode, .appShell)
        XCTAssertEqual(resolver.resolve(arguments: ["app", "--screen", "main"]).remainingArguments, ["--screen", "main"])
        XCTAssertEqual(resolver.resolve(arguments: ["launch-app"]).mode, .appShell)
    }

    func testHelpFlagsResolveToHelpMode() {
        let resolver = AppExecutableModeResolver()

        XCTAssertEqual(resolver.resolve(arguments: ["--help"]).mode, .help)
        XCTAssertEqual(resolver.resolve(arguments: ["-h"]).mode, .help)
    }

    func testDoubleDashPassesRemainingArgumentsToCLIMode() {
        let resolution = AppExecutableModeResolver().resolve(arguments: ["--", "--app", "status"])

        XCTAssertEqual(resolution.mode, .cli)
        XCTAssertEqual(resolution.remainingArguments, ["--app", "status"])
    }

    func testKnownCLISubcommandsResolveToCLIMode() {
        let resolver = AppExecutableModeResolver()

        XCTAssertEqual(resolver.resolve(arguments: ["status"]).mode, .cli)
        XCTAssertEqual(resolver.resolve(arguments: ["jump", "session-1"]).remainingArguments, ["jump", "session-1"])
        XCTAssertEqual(resolver.resolve(arguments: ["sync-opencode"]).mode, .cli)
        XCTAssertEqual(resolver.resolve(arguments: ["runtime"]).mode, .cli)
    }

    func testUnknownTopLevelSwitchResolvesToInvalidWithDiagnostic() {
        let resolution = AppExecutableModeResolver().resolve(arguments: ["--unknown"])

        XCTAssertEqual(resolution.mode, .invalid)
        XCTAssertEqual(resolution.remainingArguments, ["--unknown"])
        XCTAssertEqual(resolution.diagnostic, "unknown top-level option: --unknown")
    }

    func testResolutionRoundTripsThroughJSON() throws {
        let resolution = AppExecutableModeResolution(
            mode: .invalid,
            remainingArguments: ["--unknown"],
            diagnostic: "unknown top-level option: --unknown"
        )

        let decoded = try JSONDecoder().decode(
            AppExecutableModeResolution.self,
            from: try JSONEncoder().encode(resolution)
        )

        XCTAssertEqual(decoded, resolution)
    }
}

private struct AppExecutableModeMatrixFixture: Codable, Equatable {
    let rows: [AppExecutableModeMatrixRow]
}

private struct AppExecutableModeMatrixRow: Codable, Equatable {
    let id: String
    let mode: AppExecutableMode
    let remainingArguments: [String]
    let diagnostic: String?

    init(id: String, resolution: AppExecutableModeResolution) {
        self.id = id
        mode = resolution.mode
        remainingArguments = resolution.remainingArguments
        diagnostic = resolution.diagnostic
    }
}
