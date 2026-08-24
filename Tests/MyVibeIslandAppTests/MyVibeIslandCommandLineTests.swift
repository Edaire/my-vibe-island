import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandCommandLineTests: XCTestCase {
    func testCommandLineAppShellMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CommandLineAppShellMatrixFixture.self,
            from: try AppFixtureLoader.data("app/command-line-app-shell-matrix")
        )

        var launchCount = 0
        let actual = CommandLineAppShellMatrixFixture(rows: [
            try row(
                id: "dry-run-app-shell",
                arguments: ["--app", "--dry-run"],
                commandLine: MyVibeIslandCommandLine()
            ),
            try row(
                id: "explicit-appkit-launch",
                arguments: ["--app", "--run-appkit"],
                commandLine: MyVibeIslandCommandLine(
                    appKitLauncher: {
                        launchCount += 1
                        return Self.appKitLaunchResult(platformIntentCount: 36)
                    }
                )
            )
        ])

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(launchCount, 1)
    }

    func testAppModeUsesApplicationLaunchPlanOutput() throws {
        let output = try MyVibeIslandCommandLine().run(arguments: ["--app", "--dry-run"])

        XCTAssertTrue(output.contains("My Vibe Island app shell"))
        XCTAssertTrue(output.contains("launch mode: dryRun"))
        XCTAssertTrue(output.contains("target: Built-in Display"))
        XCTAssertTrue(output.contains("platform intents: 36"))
        XCTAssertTrue(output.contains("lifecycle intents: 10"))
        XCTAssertTrue(output.contains("runtime start intents: 19"))
        XCTAssertTrue(output.contains("notch window intents: 5"))
        XCTAssertTrue(output.contains("route intents: 1"))
        XCTAssertTrue(output.contains("platform intent plan: lifecycle, runtime, notch, statusMenu, route"))
        XCTAssertTrue(output.contains("platform launch: skipped (dry run)"))
    }

    func testAppModeCanRequestAppKitLaunchExplicitly() throws {
        var launchCount = 0
        let output = try MyVibeIslandCommandLine(
            appKitLauncher: {
                launchCount += 1
                return MyVibeIslandAppKitLaunchResult(
                    runPlan: MyVibeIslandAppKitRunPlan(
                        delegate: MyVibeIslandAppKitDelegate(),
                        intents: [
                            .setActivationPolicy(.accessory),
                            .installDelegate,
                            .runApplication
                        ]
                    ),
                    executedIntents: [
                        .setActivationPolicy(.accessory),
                        .installDelegate,
                        .runApplication
                    ],
                    platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult(
                        executedIntents: Array(repeating: .showIsland, count: 36)
                    )
                )
            }
        ).run(arguments: ["--app", "--run-appkit"])

        XCTAssertTrue(output.contains("My Vibe Island app shell"))
        XCTAssertTrue(output.contains("launch mode: appKit"))
        XCTAssertTrue(output.contains("platform intents: 36"))
        XCTAssertTrue(output.contains("appkit runner intents: 3"))
        XCTAssertTrue(output.contains("platform launch: executed"))
        XCTAssertTrue(output.contains("appkit executed intents: 3"))
        XCTAssertTrue(output.contains("appkit executed platform intents: 36"))
        XCTAssertFalse(output.contains("arguments: --run-appkit"))
        XCTAssertEqual(launchCount, 1)
    }

    func testNoArgumentsLaunchAppKitByDefault() throws {
        var launchCount = 0
        let output = try MyVibeIslandCommandLine(
            appKitLauncher: {
                launchCount += 1
                return Self.appKitLaunchResult(platformIntentCount: 36)
            }
        ).run(arguments: [])

        XCTAssertTrue(output.contains("launch mode: appKit"))
        XCTAssertTrue(output.contains("platform launch: executed"))
        XCTAssertEqual(launchCount, 1)
    }

    func testCLIModeDelegatesToCoreCLI() throws {
        let output = try MyVibeIslandCommandLine(
            coreCLI: AppCLI(runtimeFactory: {
                AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
            })
        ).run(arguments: ["status"])

        XCTAssertTrue(output.contains("My Vibe Island runtime status"))
        XCTAssertTrue(output.contains("bridge: stopped"))
    }

    private func row(
        id: String,
        arguments: [String],
        commandLine: MyVibeIslandCommandLine
    ) throws -> CommandLineAppShellMatrixRow {
        let output = try commandLine.run(arguments: arguments)
        return CommandLineAppShellMatrixRow(
            id: id,
            arguments: arguments,
            outputLines: output.components(separatedBy: "\n")
        )
    }

    private static func appKitLaunchResult(platformIntentCount: Int) -> MyVibeIslandAppKitLaunchResult {
        MyVibeIslandAppKitLaunchResult(
            runPlan: MyVibeIslandAppKitRunPlan(
                delegate: MyVibeIslandAppKitDelegate(),
                intents: [
                    .setActivationPolicy(.accessory),
                    .installDelegate,
                    .runApplication
                ]
            ),
            executedIntents: [
                .setActivationPolicy(.accessory),
                .installDelegate,
                .runApplication
            ],
            platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult(
                executedIntents: Array(repeating: .showIsland, count: platformIntentCount)
            )
        )
    }
}

private struct CommandLineAppShellMatrixFixture: Codable, Equatable {
    let rows: [CommandLineAppShellMatrixRow]
}

private struct CommandLineAppShellMatrixRow: Codable, Equatable {
    let id: String
    let arguments: [String]
    let outputLines: [String]
}
