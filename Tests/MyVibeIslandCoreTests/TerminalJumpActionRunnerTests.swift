import XCTest
@testable import MyVibeIslandCore

final class TerminalJumpActionRunnerTests: XCTestCase {
    private enum TestAutomationError: Error {
        case failed
    }

    private final class RecordingActionRunner: TerminalJumpActionRunning, @unchecked Sendable {
        private(set) var actions: [TerminalJumpActionDescription] = []
        private let result: TerminalJumpRunnerResult

        init(result: TerminalJumpRunnerResult) {
            self.result = result
        }

        func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
            actions.append(action)
            return result
        }
    }

    private final class RecordingCLILauncher: @unchecked Sendable {
        private(set) var launches: [(commandPath: String, arguments: [String])] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func launch(commandPath: String, arguments: [String]) -> Bool {
            launches.append((commandPath, arguments))
            return shouldSucceed
        }
    }

    private final class RecordingSocketSender: @unchecked Sendable {
        private(set) var sends: [(target: String, arguments: [String])] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func send(target: String, arguments: [String]) -> Bool {
            sends.append((target: target, arguments: arguments))
            return shouldSucceed
        }
    }

    private final class RecordingUnixSocketTransport: @unchecked Sendable {
        private(set) var sends: [(path: String, payload: Data)] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool = true) {
            self.shouldSucceed = shouldSucceed
        }

        func send(path: String, payload: Data) -> Bool {
            sends.append((path, payload))
            return shouldSucceed
        }
    }

    private final class RecordingURLOpener: @unchecked Sendable {
        private(set) var urls: [URL] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func open(_ url: URL) -> Bool {
            urls.append(url)
            return shouldSucceed
        }
    }

    private final class RecordingApplicationActivator: @unchecked Sendable {
        private(set) var bundleIds: [String] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func activate(bundleId: String) -> Bool {
            bundleIds.append(bundleId)
            return shouldSucceed
        }
    }

    private final class RecordingAutomationExecutor: @unchecked Sendable {
        private(set) var runs: [(target: String, arguments: [String])] = []
        private let result: AutomationRunResult

        init(result: AutomationRunResult) {
            self.result = result
        }

        func run(target: String, arguments: [String]) -> AutomationRunResult {
            runs.append((target: target, arguments: arguments))
            return result
        }
    }

    private final class RecordingAutomationLauncher: @unchecked Sendable {
        private(set) var launches: [[String]] = []
        private let result: AutomationRunResult

        init(result: AutomationRunResult) {
            self.result = result
        }

        func launch(arguments: [String]) -> AutomationRunResult {
            launches.append(arguments)
            return result
        }
    }

    func testTerminalJumpActionRunnerRoutingMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalJumpActionRunnerRoutingMatrixFixture.self,
            from: try FixtureLoader.data("terminal/action-runner-routing-matrix")
        )

        let actual = TerminalJumpActionRunnerRoutingMatrixFixture(rows: routingCases().map { testCase in
            let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
            let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
            let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
            let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
            let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
            let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))

            let result = TerminalJumpActionRunner(
                workspaceRunner: workspaceRunner,
                cliRunner: cliRunner,
                socketRunner: socketRunner,
                urlRunner: urlRunner,
                applicationRunner: applicationRunner,
                automationRunner: automationRunner
            ).run(testCase.action)

            return TerminalJumpActionRunnerRoutingMatrixRow(
                id: testCase.id,
                actionKind: testCase.action.kind.rawValue,
                status: result.status.rawValue,
                failureReason: result.failureReason?.rawValue,
                diagnosticSummary: result.diagnosticSummary,
                workspaceActionCount: workspaceRunner.actions.count,
                cliActionCount: cliRunner.actions.count,
                socketActionCount: socketRunner.actions.count,
                urlActionCount: urlRunner.actions.count,
                applicationActionCount: applicationRunner.actions.count,
                automationActionCount: automationRunner.actions.count
            )
        })

        XCTAssertEqual(actual, expected)
    }

    func testDelegatingRunnerRoutesWorkspaceActionsToWorkspaceRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .openWorkspace,
            summary: "open workspace",
            target: "/tmp/project",
            handlerId: "workspace"
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "workspace opened")
        XCTAssertEqual(workspaceRunner.actions, [action])
        XCTAssertEqual(cliRunner.actions, [])
        XCTAssertEqual(socketRunner.actions, [])
        XCTAssertEqual(urlRunner.actions, [])
        XCTAssertEqual(applicationRunner.actions, [])
        XCTAssertEqual(automationRunner.actions, [])
    }

    func testDelegatingRunnerRoutesCLIActionsToCLIRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .runCLI,
            summary: "run CLI handler",
            target: "tmux",
            handlerId: "tmux",
            arguments: ["select-pane", "-t", "%7"]
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "cli ran")
        XCTAssertEqual(workspaceRunner.actions, [])
        XCTAssertEqual(cliRunner.actions, [action])
        XCTAssertEqual(socketRunner.actions, [])
        XCTAssertEqual(urlRunner.actions, [])
        XCTAssertEqual(applicationRunner.actions, [])
        XCTAssertEqual(automationRunner.actions, [])
    }

    func testDelegatingRunnerRoutesSocketActionsToSocketRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .sendSocketRequest,
            summary: "send socket request",
            target: "supacode",
            handlerId: "supacode",
            arguments: ["--socket", "/tmp/supacode.sock", "surface.focus", "surface-3"]
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "socket sent")
        XCTAssertEqual(workspaceRunner.actions, [])
        XCTAssertEqual(cliRunner.actions, [])
        XCTAssertEqual(socketRunner.actions, [action])
        XCTAssertEqual(urlRunner.actions, [])
        XCTAssertEqual(applicationRunner.actions, [])
        XCTAssertEqual(automationRunner.actions, [])
    }

    func testDelegatingRunnerRoutesURLActionsToURLRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .openURL,
            summary: "open URL",
            target: "codex://threads/t1",
            handlerId: "codex-deeplink"
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "URL opened")
        XCTAssertEqual(workspaceRunner.actions, [])
        XCTAssertEqual(cliRunner.actions, [])
        XCTAssertEqual(socketRunner.actions, [])
        XCTAssertEqual(urlRunner.actions, [action])
        XCTAssertEqual(applicationRunner.actions, [])
        XCTAssertEqual(automationRunner.actions, [])
    }

    func testDelegatingRunnerRoutesApplicationActionsToApplicationRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .activateApplication,
            summary: "activate application",
            target: "com.apple.Terminal",
            handlerId: "application"
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "application activated")
        XCTAssertEqual(workspaceRunner.actions, [])
        XCTAssertEqual(cliRunner.actions, [])
        XCTAssertEqual(socketRunner.actions, [])
        XCTAssertEqual(urlRunner.actions, [])
        XCTAssertEqual(applicationRunner.actions, [action])
        XCTAssertEqual(automationRunner.actions, [])
    }

    func testDelegatingRunnerRoutesAutomationActionsToAutomationRunner() {
        let workspaceRunner = RecordingActionRunner(result: .succeeded("workspace opened"))
        let cliRunner = RecordingActionRunner(result: .succeeded("cli ran"))
        let socketRunner = RecordingActionRunner(result: .succeeded("socket sent"))
        let urlRunner = RecordingActionRunner(result: .succeeded("URL opened"))
        let applicationRunner = RecordingActionRunner(result: .succeeded("application activated"))
        let automationRunner = RecordingActionRunner(result: .succeeded("automation ran"))
        let action = TerminalJumpActionDescription(
            kind: .runAutomation,
            summary: "run automation",
            target: "com.googlecode.iterm2",
            handlerId: "iterm",
            arguments: ["tell application id \"com.googlecode.iterm2\" to activate"]
        )

        let result = TerminalJumpActionRunner(
            workspaceRunner: workspaceRunner,
            cliRunner: cliRunner,
            socketRunner: socketRunner,
            urlRunner: urlRunner,
            applicationRunner: applicationRunner,
            automationRunner: automationRunner
        ).run(action)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "automation ran")
        XCTAssertEqual(workspaceRunner.actions, [])
        XCTAssertEqual(cliRunner.actions, [])
        XCTAssertEqual(socketRunner.actions, [])
        XCTAssertEqual(urlRunner.actions, [])
        XCTAssertEqual(applicationRunner.actions, [])
        XCTAssertEqual(automationRunner.actions, [action])
    }

    func testDelegatingRunnerRejectsUnsupportedActionKinds() {
        let result = TerminalJumpActionRunner(
            workspaceRunner: RecordingActionRunner(result: .succeeded("workspace opened")),
            cliRunner: RecordingActionRunner(result: .succeeded("cli ran")),
            socketRunner: RecordingActionRunner(result: .succeeded("socket sent")),
            urlRunner: RecordingActionRunner(result: .succeeded("URL opened")),
            applicationRunner: RecordingActionRunner(result: .succeeded("application activated")),
            automationRunner: RecordingActionRunner(result: .succeeded("automation ran"))
        ).run(TerminalJumpActionDescription(
            kind: .showRepair,
            summary: "show repair",
            target: "Reconnect terminal"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "terminal action runner unsupported action: showRepair")
    }

    func testCLIRunnerLaunchesResolvedCommandWithArguments() {
        let launcher = RecordingCLILauncher(shouldSucceed: true)
        let runner = CLIActionRunner(
            commandResolver: { command in command == "tmux" ? "/opt/homebrew/bin/tmux" : nil },
            launch: launcher.launch
        )

        let result = runner.run(TerminalJumpActionDescription(
            kind: .runCLI,
            summary: "run CLI handler",
            target: "tmux",
            handlerId: "tmux",
            arguments: ["select-pane", "-t", "%7"]
        ))

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "ran CLI handler tmux")
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches.first?.commandPath, "/opt/homebrew/bin/tmux")
        XCTAssertEqual(launcher.launches.first?.arguments, ["select-pane", "-t", "%7"])
    }

    func testCLIRunnerRejectsUnsupportedActionWithoutLaunching() {
        let launcher = RecordingCLILauncher(shouldSucceed: true)
        let runner = CLIActionRunner(
            commandResolver: { _ in "/bin/echo" },
            launch: launcher.launch
        )

        let result = runner.run(TerminalJumpActionDescription(kind: .openWorkspace, summary: "open workspace", target: "/tmp/project"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "cli runner unsupported action: openWorkspace")
        XCTAssertEqual(launcher.launches.count, 0)
    }

    func testCLIRunnerRejectsMissingTargetWithoutLaunching() {
        let launcher = RecordingCLILauncher(shouldSucceed: true)
        let runner = CLIActionRunner(
            commandResolver: { _ in "/bin/echo" },
            launch: launcher.launch
        )

        let result = runner.run(TerminalJumpActionDescription(kind: .runCLI, summary: "run CLI handler"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "cli runner missing target")
        XCTAssertEqual(launcher.launches.count, 0)
    }

    func testCLIRunnerReportsMissingCommandWithoutLaunching() {
        let launcher = RecordingCLILauncher(shouldSucceed: true)
        let runner = CLIActionRunner(
            commandResolver: { _ in nil },
            launch: launcher.launch
        )

        let result = runner.run(TerminalJumpActionDescription(kind: .runCLI, summary: "run CLI handler", target: "tmux"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .dependencyMissing)
        XCTAssertEqual(result.diagnosticSummary, "missing CLI command: tmux")
        XCTAssertEqual(launcher.launches.count, 0)
    }

    func testCLIRunnerMapsLaunchFailureToExecutionFailed() {
        let runner = CLIActionRunner(
            commandResolver: { _ in "/opt/homebrew/bin/tmux" },
            launch: RecordingCLILauncher(shouldSucceed: false).launch
        )

        let result = runner.run(TerminalJumpActionDescription(
            kind: .runCLI,
            summary: "run CLI handler",
            target: "tmux",
            arguments: ["select-pane", "-t", "%7"]
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to run CLI handler tmux")
    }

    func testSocketRunnerSendsTargetAndArguments() {
        let sender = RecordingSocketSender(shouldSucceed: true)
        let runner = SocketActionRunner(send: sender.send)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .sendSocketRequest,
            summary: "send socket request",
            target: "supacode",
            handlerId: "supacode",
            arguments: ["--socket", "/tmp/supacode.sock", "surface.focus", "surface-3"]
        ))

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "sent socket request for supacode")
        XCTAssertEqual(sender.sends.count, 1)
        XCTAssertEqual(sender.sends.first?.target, "supacode")
        XCTAssertEqual(sender.sends.first?.arguments, ["--socket", "/tmp/supacode.sock", "surface.focus", "surface-3"])
    }

    func testSocketRunnerRejectsUnsupportedActionWithoutSending() {
        let sender = RecordingSocketSender(shouldSucceed: true)
        let runner = SocketActionRunner(send: sender.send)

        let result = runner.run(TerminalJumpActionDescription(kind: .runCLI, summary: "run CLI handler", target: "tmux"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "socket runner unsupported action: runCLI")
        XCTAssertEqual(sender.sends.count, 0)
    }

    func testSocketRunnerRejectsMissingTargetWithoutSending() {
        let sender = RecordingSocketSender(shouldSucceed: true)
        let runner = SocketActionRunner(send: sender.send)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .sendSocketRequest,
            summary: "send socket request",
            arguments: ["--socket", "/tmp/cmux.sock", "surface.focus", "surface-7"]
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "socket runner missing target")
        XCTAssertEqual(sender.sends.count, 0)
    }

    func testSocketRunnerRejectsMissingArgumentsWithoutSending() {
        let sender = RecordingSocketSender(shouldSucceed: true)
        let runner = SocketActionRunner(send: sender.send)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .sendSocketRequest,
            summary: "send socket request",
            target: "cmux"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "socket runner missing arguments for cmux")
        XCTAssertEqual(sender.sends.count, 0)
    }

    func testSocketRunnerMapsSendFailureToExecutionFailed() {
        let runner = SocketActionRunner(send: RecordingSocketSender(shouldSucceed: false).send)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .sendSocketRequest,
            summary: "send socket request",
            target: "cmux",
            arguments: ["--socket", "/tmp/cmux.sock", "surface.focus", "surface-7"]
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to send socket request for cmux")
    }

    func testSystemUnixSocketSenderBuildsAllowlistedCmuxJSONRPCPayload() throws {
        let transport = RecordingUnixSocketTransport()
        let sender = SystemUnixSocketSender(transport: transport.send)

        XCTAssertTrue(sender.send(
            target: "cmux",
            arguments: ["--socket", "/tmp/cmux.sock", "surface.focus", "surface-7"]
        ))

        XCTAssertEqual(transport.sends.first?.path, "/tmp/cmux.sock")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(transport.sends.first?.payload)) as? [String: Any]
        )
        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["method"] as? String, "surface.focus")
        XCTAssertEqual((object["params"] as? [String: String])?["surface_id"], "surface-7")
        XCTAssertEqual(object["id"] as? Int, 1)
        XCTAssertEqual(transport.sends.first?.payload.last, 0x0A)
    }

    func testSystemUnixSocketSenderRejectsUnverifiedTargetsMethodsAndPaths() {
        let transport = RecordingUnixSocketTransport()
        let sender = SystemUnixSocketSender(transport: transport.send)

        XCTAssertFalse(sender.send(target: "otty", arguments: ["--socket", "/tmp/otty.sock", "focus-pane", "7"]))
        XCTAssertFalse(sender.send(target: "cmux", arguments: ["--socket", "relative.sock", "surface.focus", "7"]))
        XCTAssertFalse(sender.send(target: "cmux", arguments: ["--socket", "/tmp/cmux.sock", "tab.focus", "7"]))
        XCTAssertFalse(sender.send(target: "cmux", arguments: ["--socket", "/tmp/cmux.sock", "surface.focus"]))
        XCTAssertEqual(transport.sends.count, 0)
    }

    func testURLRunnerOpensParsedURL() {
        let opener = RecordingURLOpener(shouldSucceed: true)
        let runner = URLActionRunner(open: opener.open)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .openURL,
            summary: "open URL",
            target: "codex://threads/t1",
            handlerId: "codex-deeplink"
        ))

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "opened URL: codex://threads/t1")
        XCTAssertEqual(opener.urls.map(\.absoluteString), ["codex://threads/t1"])
    }

    func testURLRunnerRejectsUnsupportedActionWithoutOpening() {
        let opener = RecordingURLOpener(shouldSucceed: true)
        let runner = URLActionRunner(open: opener.open)

        let result = runner.run(TerminalJumpActionDescription(kind: .runCLI, summary: "run CLI handler", target: "tmux"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "URL runner unsupported action: runCLI")
        XCTAssertEqual(opener.urls, [])
    }

    func testURLRunnerRejectsMissingTargetWithoutOpening() {
        let opener = RecordingURLOpener(shouldSucceed: true)
        let runner = URLActionRunner(open: opener.open)

        let result = runner.run(TerminalJumpActionDescription(kind: .openURL, summary: "open URL"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "URL runner missing target")
        XCTAssertEqual(opener.urls, [])
    }

    func testURLRunnerRejectsInvalidURLWithoutOpening() {
        let opener = RecordingURLOpener(shouldSucceed: true)
        let runner = URLActionRunner(open: opener.open)

        let result = runner.run(TerminalJumpActionDescription(kind: .openURL, summary: "open URL", target: "not a url"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "URL runner invalid URL: not a url")
        XCTAssertEqual(opener.urls, [])
    }

    func testURLRunnerReportsMissingSchemeHandlerWithoutOpening() {
        let opener = RecordingURLOpener(shouldSucceed: true)
        let runner = URLActionRunner(
            canOpen: { _ in false },
            open: opener.open
        )

        let result = runner.run(TerminalJumpActionDescription(
            kind: .openURL,
            summary: "open URL",
            target: "codex://threads/t1",
            handlerId: "codex-deeplink"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .dependencyMissing)
        XCTAssertEqual(result.diagnosticSummary, "missing URL scheme handler: codex")
        XCTAssertEqual(opener.urls, [])
    }

    func testURLRunnerMapsOpenFailureToExecutionFailed() {
        let runner = URLActionRunner(open: RecordingURLOpener(shouldSucceed: false).open)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .openURL,
            summary: "open URL",
            target: "warp://focus"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to open URL: warp://focus")
    }

    func testURLRunnerStillMapsOpenFailureWhenSchemeHandlerExists() {
        let runner = URLActionRunner(
            canOpen: { _ in true },
            open: RecordingURLOpener(shouldSucceed: false).open
        )

        let result = runner.run(TerminalJumpActionDescription(
            kind: .openURL,
            summary: "open URL",
            target: "warp://focus",
            handlerId: "warp"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to open URL: warp://focus")
    }

    func testApplicationRunnerActivatesTargetBundleIdentifier() {
        let activator = RecordingApplicationActivator(shouldSucceed: true)
        let runner = ApplicationActionRunner(activate: activator.activate)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .activateApplication,
            summary: "activate application",
            target: "com.apple.Terminal",
            handlerId: "application"
        ))

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "activated application: com.apple.Terminal")
        XCTAssertEqual(activator.bundleIds, ["com.apple.Terminal"])
    }

    func testApplicationRunnerRejectsUnsupportedActionWithoutActivating() {
        let activator = RecordingApplicationActivator(shouldSucceed: true)
        let runner = ApplicationActionRunner(activate: activator.activate)

        let result = runner.run(TerminalJumpActionDescription(kind: .openURL, summary: "open URL", target: "codex://threads/t1"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "application runner unsupported action: openURL")
        XCTAssertEqual(activator.bundleIds, [])
    }

    func testApplicationRunnerRejectsMissingTargetWithoutActivating() {
        let activator = RecordingApplicationActivator(shouldSucceed: true)
        let runner = ApplicationActionRunner(activate: activator.activate)

        let result = runner.run(TerminalJumpActionDescription(kind: .activateApplication, summary: "activate application"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "application runner missing target")
        XCTAssertEqual(activator.bundleIds, [])
    }

    func testApplicationRunnerMapsActivationFailureToExecutionFailed() {
        let runner = ApplicationActionRunner(activate: RecordingApplicationActivator(shouldSucceed: false).activate)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .activateApplication,
            summary: "activate application",
            target: "com.missing.App",
            handlerId: "application"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to activate application: com.missing.App")
    }

    func testAutomationRunnerRunsTargetWithArguments() {
        let executor = RecordingAutomationExecutor(result: .succeeded)
        let runner = AutomationActionRunner(runAutomation: executor.run)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .runAutomation,
            summary: "run automation",
            target: "com.googlecode.iterm2",
            handlerId: "iterm",
            arguments: ["tell application id \"com.googlecode.iterm2\" to activate"]
        ))

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "ran automation for com.googlecode.iterm2")
        XCTAssertEqual(executor.runs.count, 1)
        XCTAssertEqual(executor.runs.first?.target, "com.googlecode.iterm2")
        XCTAssertEqual(executor.runs.first?.arguments, ["tell application id \"com.googlecode.iterm2\" to activate"])
    }

    func testAutomationRunnerRejectsUnsupportedActionWithoutRunning() {
        let executor = RecordingAutomationExecutor(result: .succeeded)
        let runner = AutomationActionRunner(runAutomation: executor.run)

        let result = runner.run(TerminalJumpActionDescription(kind: .runCLI, summary: "run CLI handler", target: "tmux"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "automation runner unsupported action: runCLI")
        XCTAssertEqual(executor.runs.count, 0)
    }

    func testAutomationRunnerRejectsMissingTargetWithoutRunning() {
        let executor = RecordingAutomationExecutor(result: .succeeded)
        let runner = AutomationActionRunner(runAutomation: executor.run)

        let result = runner.run(TerminalJumpActionDescription(kind: .runAutomation, summary: "run automation"))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "automation runner missing target")
        XCTAssertEqual(executor.runs.count, 0)
    }

    func testAutomationRunnerMapsFailureToExecutionFailed() {
        let runner = AutomationActionRunner(runAutomation: RecordingAutomationExecutor(result: .failed).run)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .runAutomation,
            summary: "run automation",
            target: "com.apple.Terminal",
            handlerId: "terminal-tty"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to run automation for com.apple.Terminal")
    }

    func testAutomationRunnerMapsPermissionDeniedToPermissionDenied() {
        let runner = AutomationActionRunner(runAutomation: RecordingAutomationExecutor(result: .permissionDenied).run)

        let result = runner.run(TerminalJumpActionDescription(
            kind: .runAutomation,
            summary: "run automation",
            target: "com.apple.Terminal",
            handlerId: "terminal-tty"
        ))

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .permissionDenied)
        XCTAssertEqual(result.diagnosticSummary, "automation permission denied for com.apple.Terminal")
    }

    func testSystemAutomationRunnerConvertsScriptLinesToOsaScriptArguments() {
        let launcher = RecordingAutomationLauncher(result: .succeeded)
        let runner = SystemAutomationRunner(launch: launcher.launch)

        let result = runner.run(target: "com.apple.Terminal", arguments: [
            "tell application id \"com.apple.Terminal\"",
            "activate",
            "end tell"
        ])

        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(launcher.launches, [[
            "-e",
            "tell application id \"com.apple.Terminal\"",
            "-e",
            "activate",
            "-e",
            "end tell"
        ]])
    }

    func testSystemAutomationRunnerRejectsEmptyScriptArgumentsWithoutLaunching() {
        let launcher = RecordingAutomationLauncher(result: .succeeded)
        let runner = SystemAutomationRunner(launch: launcher.launch)

        let result = runner.run(target: "com.apple.Terminal", arguments: [])

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(launcher.launches, [])
    }

    func testSystemAutomationProcessLauncherMapsZeroTerminationStatusToSucceeded() {
        let launcher = SystemAutomationProcessLauncher { _ in
            AutomationProcessResult(terminationStatus: 0, standardError: "")
        }

        XCTAssertEqual(launcher.launch(arguments: ["-e", "return"]), .succeeded)
    }

    func testSystemAutomationProcessLauncherMapsAppleEventDenialToPermissionDenied() {
        let launcher = SystemAutomationProcessLauncher { _ in
            AutomationProcessResult(
                terminationStatus: 1,
                standardError: "Not authorized to send Apple events. (-1743)"
            )
        }

        XCTAssertEqual(launcher.launch(arguments: ["-e", "tell application id \"com.apple.Terminal\""]), .permissionDenied)
    }

    func testSystemAutomationProcessLauncherMapsUnrelatedNonzeroStatusToFailed() {
        let launcher = SystemAutomationProcessLauncher { _ in
            AutomationProcessResult(terminationStatus: 1, standardError: "script syntax error")
        }

        XCTAssertEqual(launcher.launch(arguments: ["-e", "broken"]), .failed)
    }

    func testSystemAutomationProcessLauncherMapsThrownExecutionErrorToFailed() {
        let launcher = SystemAutomationProcessLauncher { _ in
            throw TestAutomationError.failed
        }

        XCTAssertEqual(launcher.launch(arguments: ["-e", "return"]), .failed)
    }

    private func routingCases() -> [(id: String, action: TerminalJumpActionDescription)] {
        [
            (
                id: "workspace-action",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/project",
                    handlerId: "workspace"
                )
            ),
            (
                id: "cli-action",
                action: TerminalJumpActionDescription(
                    kind: .runCLI,
                    summary: "run CLI handler",
                    target: "tmux",
                    handlerId: "tmux",
                    arguments: ["select-pane", "-t", "%7"]
                )
            ),
            (
                id: "socket-action",
                action: TerminalJumpActionDescription(
                    kind: .sendSocketRequest,
                    summary: "send socket request",
                    target: "supacode",
                    handlerId: "supacode",
                    arguments: ["--socket", "/tmp/supacode.sock", "surface.focus", "surface-3"]
                )
            ),
            (
                id: "url-action",
                action: TerminalJumpActionDescription(
                    kind: .openURL,
                    summary: "open URL",
                    target: "codex://threads/t1",
                    handlerId: "codex-deeplink"
                )
            ),
            (
                id: "application-action",
                action: TerminalJumpActionDescription(
                    kind: .activateApplication,
                    summary: "activate application",
                    target: "com.apple.Terminal",
                    handlerId: "application"
                )
            ),
            (
                id: "automation-action",
                action: TerminalJumpActionDescription(
                    kind: .runAutomation,
                    summary: "run automation",
                    target: "com.googlecode.iterm2",
                    handlerId: "iterm",
                    arguments: ["tell application id \"com.googlecode.iterm2\" to activate"]
                )
            ),
            (
                id: "unsupported-repair-action",
                action: TerminalJumpActionDescription(
                    kind: .showRepair,
                    summary: "show repair",
                    target: "Reconnect terminal"
                )
            ),
        ]
    }

    private struct TerminalJumpActionRunnerRoutingMatrixFixture: Codable, Equatable {
        let rows: [TerminalJumpActionRunnerRoutingMatrixRow]
    }

    private struct TerminalJumpActionRunnerRoutingMatrixRow: Codable, Equatable {
        let id: String
        let actionKind: String
        let status: String
        let failureReason: String?
        let diagnosticSummary: String
        let workspaceActionCount: Int
        let cliActionCount: Int
        let socketActionCount: Int
        let urlActionCount: Int
        let applicationActionCount: Int
        let automationActionCount: Int
    }
}
