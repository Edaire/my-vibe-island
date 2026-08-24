import XCTest
@testable import MyVibeIslandCore

final class TerminalJumpExecutorTests: XCTestCase {
    private struct ActionFixture: Decodable {
        let handlerId: String
        let precision: JumpPrecision
        let expectedAction: TerminalJumpActionDescription
    }

    private struct ResolvedActionFixture: Decodable {
        let name: String
        let handlerId: String
        let precision: JumpPrecision
        let input: JumpInput
        let expectedAction: TerminalJumpActionDescription
    }

    private final class RecordingJumpRunner: TerminalJumpActionRunning, @unchecked Sendable {
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

    func testDryRunActionsMatchFixtureForEveryDefaultHandler() throws {
        let fixtures = try JSONDecoder().decode(
            [ActionFixture].self,
            from: try FixtureLoader.data("terminal/default-action-dry-runs")
        )

        XCTAssertEqual(fixtures.map(\.handlerId), TerminalRegistry.default.descriptors.map(\.id))

        for fixture in fixtures {
            let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
                sessionId: "fixture-\(fixture.handlerId)",
                status: .planned,
                handlerId: fixture.handlerId,
                precision: fixture.precision,
                diagnosticSummary: "\(fixture.handlerId): \(fixture.precision.rawValue)"
            ))

            XCTAssertEqual(result.status, .dryRun, fixture.handlerId)
            XCTAssertEqual(result.actionDescription, fixture.expectedAction, fixture.handlerId)
        }
    }

    func testDryRunResolvedTargetActionsMatchArgumentFixtures() throws {
        let fixtures = try JSONDecoder().decode(
            [ResolvedActionFixture].self,
            from: try FixtureLoader.data("terminal/resolved-action-dry-runs")
        )

        for fixture in fixtures {
            let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
                sessionId: "fixture-\(fixture.name)",
                status: .planned,
                handlerId: fixture.handlerId,
                precision: fixture.precision,
                diagnosticSummary: "\(fixture.handlerId): \(fixture.precision.rawValue)",
                resolvedTarget: TerminalResolver().resolve(fixture.input)
            ))

            XCTAssertEqual(result.status, .dryRun, fixture.name)
            XCTAssertEqual(result.actionDescription, fixture.expectedAction, fixture.name)
        }
    }

    func testDryRunReportsRegisteredHandlerPermissions() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane"
        ))

        XCTAssertEqual(result.sessionId, "s1")
        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.permissionRequirements, [.cli, .automation])
        XCTAssertNil(result.blockReason)
        XCTAssertEqual(result.diagnosticSummary, "dry run: tmux exactPane")
    }

    func testRepairRequiredPlanReturnsRepairResult() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "remote",
            status: .repairRequired,
            handlerId: "remote-hint",
            precision: .remoteHint,
            failureReason: .remoteRequiresReconnect,
            repairAction: "Reconnect remote terminal before jumping",
            diagnosticSummary: "remote-hint: remoteRequiresReconnect"
        ))

        XCTAssertEqual(result.status, .repairRequired)
        XCTAssertEqual(result.handlerId, "remote-hint")
        XCTAssertEqual(result.precision, .remoteHint)
        XCTAssertEqual(result.permissionRequirements, [.none])
        XCTAssertEqual(result.blockReason, .requiresRepair)
        XCTAssertEqual(result.repairAction, "Reconnect remote terminal before jumping")
        XCTAssertEqual(result.diagnosticSummary, "remote-hint: remoteRequiresReconnect")
    }

    func testUnavailablePlanReturnsUnavailableResult() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "missing",
            status: .unavailable,
            failureReason: .missingSession,
            diagnosticSummary: "missing session"
        ))

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertNil(result.handlerId)
        XCTAssertNil(result.precision)
        XCTAssertEqual(result.permissionRequirements, [])
        XCTAssertEqual(result.blockReason, .unavailablePlan)
        XCTAssertEqual(result.diagnosticSummary, "missing session")
    }

    func testMissingHandlerBlocksExecution() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            precision: .exactPane,
            diagnosticSummary: "missing handler"
        ))

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .missingHandler)
        XCTAssertEqual(result.permissionRequirements, [])
        XCTAssertEqual(result.diagnosticSummary, "missing handler")
    }

    func testUnsupportedHandlerBlocksExecution() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "unknown-handler",
            precision: .exactPane,
            diagnosticSummary: "unknown"
        ))

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "unknown-handler")
        XCTAssertEqual(result.blockReason, .unsupportedHandler)
        XCTAssertEqual(result.permissionRequirements, [])
        XCTAssertEqual(result.diagnosticSummary, "unknown")
    }

    func testUnsupportedPrecisionForRegisteredHandlerBlocksExecution() {
        let registry = TerminalRegistry(descriptors: [
            TerminalCapabilityDescriptor(
                id: "tmux",
                displayName: "tmux",
                category: .multiplexer,
                supportLevel: .supported,
                supportedPrecisions: [.exactWindow],
                cliCommands: ["tmux"],
                permissionRequirements: [.cli]
            )
        ])
        let result = TerminalJumpExecutor(registry: registry).execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane"
        ))

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .unsupportedHandler)
        XCTAssertEqual(result.permissionRequirements, [.cli])
    }

    func testExecuteModeBlocksUntilHandlersAreImplemented() {
        let result = TerminalJumpExecutor().execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "tmux",
                precision: .exactPane,
                diagnosticSummary: "tmux: exactPane"
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.permissionRequirements, [.cli, .automation])
        XCTAssertEqual(result.blockReason, .executionNotImplemented)
        XCTAssertEqual(result.diagnosticSummary, "execution not implemented: tmux")
    }

    func testDryRunDescribesURLAction() {
        let input = JumpInput(sessionId: "s1", source: "codex", customJumpURL: "codex://threads/t1")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "custom-url",
            precision: .exactPane,
            diagnosticSummary: "custom-url: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .openURL)
        XCTAssertEqual(result.actionDescription?.target, "codex://threads/t1")
        XCTAssertEqual(result.actionDescription?.summary, "open URL")
    }

    func testDryRunDescribesWarpFocusURLAction() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            warpPaneUUID: "pane-1",
            warpFocusURL: "warp://focus/pane-1"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "warp",
            precision: .exactWindow,
            diagnosticSummary: "warp: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .openURL)
        XCTAssertEqual(result.actionDescription?.target, "warp://focus/pane-1")
        XCTAssertEqual(result.actionDescription?.handlerId, "warp")
    }

    func testDryRunDescribesWarpPaneOnlyApplicationFallbackWithDefaultBundle() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            warpPaneUUID: "pane-1"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "application",
            precision: .application,
            diagnosticSummary: "application: application",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .activateApplication)
        XCTAssertEqual(result.actionDescription?.target, "dev.warp.Warp-Stable")
        XCTAssertEqual(result.actionDescription?.handlerId, "application")
    }

    func testDryRunDescribesWorkspaceAction() {
        let input = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "workspace",
            precision: .workspace,
            diagnosticSummary: "workspace: workspace",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .openWorkspace)
        XCTAssertEqual(result.actionDescription?.target, "/tmp/project")
        XCTAssertEqual(result.actionDescription?.summary, "open workspace")
    }

    func testDryRunDescribesPerIDEWorkspaceDescriptorAsOpenWorkspace() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "cursor-workspace",
            precision: .workspace,
            diagnosticSummary: "cursor-workspace: workspace",
            resolvedTarget: TerminalResolver().resolve(JumpInput(
                sessionId: "s1",
                source: "codex",
                bundleId: "com.todesktop.230313mzl4w4u92",
                cwd: "/tmp/project"
            ))
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.actionDescription?.kind, .openWorkspace)
        XCTAssertEqual(result.actionDescription?.target, "/tmp/project")
        XCTAssertEqual(result.actionDescription?.handlerId, "cursor-workspace")
    }

    func testDryRunDescribesApplicationAction() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "application",
            precision: .application,
            diagnosticSummary: "application: application",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .activateApplication)
        XCTAssertEqual(result.actionDescription?.target, "com.apple.Terminal")
        XCTAssertEqual(result.actionDescription?.summary, "activate application")
    }

    func testDryRunDescribesClaudeDesktopApplicationActionWithBundleId() {
        let input = JumpInput(
            sessionId: "s1",
            source: "claude-desktop",
            bundleId: "com.example.ClaudeDesktop"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "claude-desktop-code",
            precision: .application,
            diagnosticSummary: "claude-desktop-code: application",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.handlerId, "claude-desktop-code")
        XCTAssertEqual(result.permissionRequirements, [.none])
        XCTAssertEqual(result.actionDescription?.kind, .activateApplication)
        XCTAssertEqual(result.actionDescription?.target, "com.example.ClaudeDesktop")
        XCTAssertEqual(result.actionDescription?.handlerId, "claude-desktop-code")
    }

    func testDryRunDescribesClaudeDesktopApplicationActionWithoutBundleId() {
        let input = JumpInput(sessionId: "s1", source: "claude-desktop")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "claude-desktop-code",
            precision: .application,
            diagnosticSummary: "claude-desktop-code: application",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.actionDescription?.kind, .activateApplication)
        XCTAssertNil(result.actionDescription?.target)
        XCTAssertEqual(result.actionDescription?.handlerId, "claude-desktop-code")
    }

    func testDryRunDescribesCLIAction() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "kitty",
            precision: .exactWindow,
            diagnosticSummary: "kitty: exactWindow"
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "kitty")
        XCTAssertEqual(result.actionDescription?.summary, "run CLI handler")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesTmuxCLIActionWithSocketAndPaneArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            tmuxPane: "%7",
            tmuxSocketPath: "/tmp/tmux-501/default"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "tmux")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "-S",
            "/tmp/tmux-501/default",
            "select-pane",
            "-t",
            "%7"
        ])
    }

    func testDryRunDescribesTmuxFocusViaAttachedTerminalClientRatherThanPaneTTY() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            tty: "/dev/ttys023",
            tmuxPane: "%1752",
            tmuxSocketPath: "/private/tmp/tmux-502/default"
        )

        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.apple.Terminal")
        XCTAssertEqual(result.actionDescription?.arguments.joined(separator: "\n"), """
        set tmuxSocketPath to \"/private/tmp/tmux-502/default\"
        set targetPane to \"%1752\"
        set tmuxCommand to do shell script \"for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do if [ -x \\\"$candidate\\\" ]; then printf '%s' \\\"$candidate\\\"; exit 0; fi; done; command -v tmux\"
        set targetSession to do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" display-message -p -t \" & quoted form of targetPane & \" '#{session_name}'\"
        set clientTTY to do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" list-clients -F '#{client_tty} #{client_session}' | /usr/bin/awk -v session=\" & quoted form of targetSession & \" '$2 == session { print $1; exit }'\"
        tell application id \"com.apple.Terminal\"
        activate
        set focusedTab to false
        repeat with candidateWindow in windows
        if not focusedTab then
        repeat with candidateTab in tabs of candidateWindow
        if tty of candidateTab is clientTTY then
        set selected tab of candidateWindow to candidateTab
        set index of candidateWindow to 1
        set focusedTab to true
        exit repeat
        end if
        end repeat
        end if
        end repeat
        if not focusedTab then error \"Terminal tab not found for tmux client\"
        end tell
        do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" switch-client -c \" & quoted form of clientTTY & \" -t \" & quoted form of targetSession
        do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" select-pane -t \" & quoted form of targetPane
        """)
        XCTAssertFalse(result.actionDescription?.arguments.joined(separator: "\n").contains("/dev/ttys023") == true)
    }

    func testDryRunDescribesTmuxCLIActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%7")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "tmux")
        XCTAssertEqual(result.actionDescription?.arguments, ["select-pane", "-t", "%7"])
    }

    func testDryRunDescribesZellijCLIActionWithSessionAndPaneArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            zellijSessionName: "work",
            zellijPaneId: "pane-7"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "zellij",
            precision: .exactPane,
            diagnosticSummary: "zellij: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "zellij")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--session",
            "work",
            "action",
            "focus-pane",
            "pane-7"
        ])
    }

    func testDryRunDescribesZellijCLIActionWithoutSessionArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", zellijPaneId: "pane-7")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "zellij",
            precision: .exactPane,
            diagnosticSummary: "zellij: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "zellij")
        XCTAssertEqual(result.actionDescription?.arguments, ["action", "focus-pane", "pane-7"])
    }

    func testDryRunDescribesWezTermCLIActionWithSocketAndPaneArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            weztermSocket: "/tmp/wezterm.sock",
            weztermPane: "42"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "wezterm",
            precision: .exactPane,
            diagnosticSummary: "wezterm: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "wezterm")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "cli",
            "--socket",
            "/tmp/wezterm.sock",
            "activate-pane",
            "--pane-id",
            "42"
        ])
    }

    func testDryRunDescribesWezTermCLIActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", weztermPane: "42")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "wezterm",
            precision: .exactPane,
            diagnosticSummary: "wezterm: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "wezterm")
        XCTAssertEqual(result.actionDescription?.arguments, ["cli", "activate-pane", "--pane-id", "42"])
    }

    func testDryRunDescribesKakuCLIActionWithSocketAndPaneArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            weztermSocket: "/tmp/kaku.sock",
            weztermPane: "42"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "kaku",
            precision: .exactPane,
            diagnosticSummary: "kaku: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.handlerId, "kaku")
        XCTAssertEqual(result.permissionRequirements, [.cli])
        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "kaku")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "cli",
            "--socket",
            "/tmp/kaku.sock",
            "activate-pane",
            "--pane-id",
            "42"
        ])
    }

    func testDryRunDescribesKakuCLIActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", weztermPane: "42")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "kaku",
            precision: .exactPane,
            diagnosticSummary: "kaku: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "kaku")
        XCTAssertEqual(result.actionDescription?.arguments, ["cli", "activate-pane", "--pane-id", "42"])
    }

    func testDryRunDescribesKittyCLIActionWithListenSocketAndWindowArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            kittyWindowId: "13",
            kittyListenOn: "unix:/tmp/kitty.sock"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "kitty",
            precision: .exactWindow,
            diagnosticSummary: "kitty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "kitty")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "@",
            "--to",
            "unix:/tmp/kitty.sock",
            "focus-window",
            "--match",
            "id:13"
        ])
    }

    func testDryRunDescribesKittyCLIActionWithoutListenSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", kittyWindowId: "13")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "kitty",
            precision: .exactWindow,
            diagnosticSummary: "kitty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runCLI)
        XCTAssertEqual(result.actionDescription?.target, "kitty")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesOttySocketActionWithSocketAndPaneArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            ottySocket: "/tmp/otty.sock",
            ottyPaneId: "pane-7"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "otty",
            precision: .exactPane,
            diagnosticSummary: "otty: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "otty")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/otty.sock",
            "focus-pane",
            "pane-7"
        ])
    }

    func testDryRunDescribesOttySocketActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", ottyPaneId: "pane-7")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "otty",
            precision: .exactPane,
            diagnosticSummary: "otty: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "otty")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesSocketAction() {
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "supacode",
            precision: .exactPane,
            diagnosticSummary: "supacode: exactPane"
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "supacode")
        XCTAssertEqual(result.actionDescription?.summary, "send socket request")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesCmuxSocketActionWithSocketAndSurfaceArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "cmux",
            cmuxSurfaceId: "surface-7",
            cmuxSocketPath: "/tmp/cmux.sock"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "cmux",
            precision: .exactPane,
            diagnosticSummary: "cmux: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "cmux")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/cmux.sock",
            "surface.focus",
            "surface-7"
        ])
    }

    func testDryRunDescribesCmuxSocketActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "cmux", cmuxSurfaceId: "surface-7")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "cmux",
            precision: .exactPane,
            diagnosticSummary: "cmux: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "cmux")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesSupacodeSocketActionWithSurfaceArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "supacode",
            supacodeWorktreeId: "worktree-1",
            supacodeTabId: "tab-2",
            supacodeSurfaceId: "surface-3",
            supacodeSocketPath: "/tmp/supacode.sock"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "supacode",
            precision: .exactPane,
            diagnosticSummary: "supacode: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "supacode")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/supacode.sock",
            "surface.focus",
            "surface-3"
        ])
    }

    func testDryRunDescribesSupacodeSocketActionWithTabArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "supacode",
            supacodeWorktreeId: "worktree-1",
            supacodeTabId: "tab-2",
            supacodeSocketPath: "/tmp/supacode.sock"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "supacode",
            precision: .exactPane,
            diagnosticSummary: "supacode: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "supacode")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/supacode.sock",
            "tab.focus",
            "tab-2"
        ])
    }

    func testDryRunDescribesSupacodeSocketActionWithWorktreeArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "supacode",
            supacodeWorktreeId: "worktree-1",
            supacodeSocketPath: "/tmp/supacode.sock"
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "supacode",
            precision: .exactPane,
            diagnosticSummary: "supacode: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "supacode")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/supacode.sock",
            "worktree.focus",
            "worktree-1"
        ])
    }

    func testDryRunDescribesSupacodeSocketActionWithoutSocketArguments() {
        let input = JumpInput(sessionId: "s1", source: "supacode", supacodeSurfaceId: "surface-3")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "supacode",
            precision: .exactPane,
            diagnosticSummary: "supacode: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.target, "supacode")
        XCTAssertEqual(result.actionDescription?.arguments, [])
    }

    func testDryRunDescribesAutomationAction() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.googlecode.iterm2", itermSessionId: "iterm-1")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "iterm",
            precision: .exactPane,
            diagnosticSummary: "iterm: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.googlecode.iterm2")
        XCTAssertEqual(result.actionDescription?.summary, "run automation")
    }

    func testDryRunDescribesTerminalAutomationActionWithTTYArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal", tty: "/dev/ttys001")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "terminal-tty",
            precision: .exactWindow,
            diagnosticSummary: "terminal-tty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.apple.Terminal")
        XCTAssertEqual(result.actionDescription?.handlerId, "terminal-tty")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.apple.Terminal\"",
            "activate",
            "repeat with candidateWindow in windows",
            "repeat with candidateTab in tabs of candidateWindow",
            "if tty of candidateTab is \"/dev/ttys001\" then",
            "set selected tab of candidateWindow to candidateTab",
            "set index of candidateWindow to 1",
            "return",
            "end if",
            "end repeat",
            "end repeat",
            "error \"Terminal tab not found for tty /dev/ttys001\"",
            "end tell"
        ])
    }

    func testDryRunDescribesTerminalAutomationActionWithoutTTYAsActivationOnly() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "terminal-tty",
            precision: .exactWindow,
            diagnosticSummary: "terminal-tty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.apple.Terminal\"",
            "activate",
            "end tell"
        ])
    }

    func testDryRunDescribesGhosttyAutomationActionWithSessionArguments() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.mitchellh.ghostty",
            isGhosttyFamilyHost: true,
            termSessionId: "ghostty-\"session\""
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "ghostty",
            precision: .exactWindow,
            diagnosticSummary: "ghostty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.mitchellh.ghostty")
        XCTAssertEqual(result.actionDescription?.handlerId, "ghostty")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.mitchellh.ghostty\"",
            "activate",
            "repeat with candidateWindow in windows",
            "set candidateWindowId to id of candidateWindow as text",
            "set candidateWindowName to name of candidateWindow as text",
            "if candidateWindowId is \"ghostty-\\\"session\\\"\" or candidateWindowName is \"ghostty-\\\"session\\\"\" then",
            "set index of candidateWindow to 1",
            "return",
            "end if",
            "end repeat",
            "error \"Ghostty window not found for session ghostty-\\\"session\\\"\"",
            "end tell"
        ])
    }

    func testDryRunDescribesGhosttyAutomationActionWithoutSessionAsActivationOnly() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.mitchellh.ghostty",
            isGhosttyFamilyHost: true
        )
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "ghostty",
            precision: .exactWindow,
            diagnosticSummary: "ghostty: exactWindow",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.mitchellh.ghostty\"",
            "activate",
            "end tell"
        ])
    }

    func testDryRunDescribesItermAutomationActionWithSessionArguments() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.googlecode.iterm2", itermSessionId: "session-\"1\"")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "iterm",
            precision: .exactPane,
            diagnosticSummary: "iterm: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.googlecode.iterm2")
        XCTAssertEqual(result.actionDescription?.handlerId, "iterm")
        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.googlecode.iterm2\"",
            "activate",
            "repeat with candidateWindow in windows",
            "repeat with candidateTab in tabs of candidateWindow",
            "repeat with candidateSession in sessions of candidateTab",
            "if id of candidateSession is \"session-\\\"1\\\"\" then",
            "select candidateWindow",
            "select candidateTab",
            "select candidateSession",
            "return",
            "end if",
            "end repeat",
            "end repeat",
            "end repeat",
            "error \"iTerm session not found for id session-\\\"1\\\"\"",
            "end tell"
        ])
    }

    func testDryRunDescribesItermAutomationActionWithoutSessionAsActivationOnly() {
        let input = JumpInput(sessionId: "s1", source: "codex", bundleId: "com.googlecode.iterm2")
        let result = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "iterm",
            precision: .exactPane,
            diagnosticSummary: "iterm: exactPane",
            resolvedTarget: TerminalResolver().resolve(input)
        ))

        XCTAssertEqual(result.actionDescription?.arguments, [
            "tell application id \"com.googlecode.iterm2\"",
            "activate",
            "end tell"
        ])
    }

    func testRepairAndUnavailableDescribeNonExecutingActions() {
        let repair = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "remote",
            status: .repairRequired,
            handlerId: "remote-hint",
            precision: .remoteHint,
            repairAction: "Reconnect remote terminal before jumping",
            diagnosticSummary: "remote-hint: remoteRequiresReconnect"
        ))
        let unavailable = TerminalJumpExecutor().execute(plan: JumpActionPlan(
            sessionId: "missing",
            status: .unavailable,
            failureReason: .missingSession,
            diagnosticSummary: "missing session"
        ))

        XCTAssertEqual(repair.actionDescription?.kind, .showRepair)
        XCTAssertEqual(repair.actionDescription?.target, "Reconnect remote terminal before jumping")
        XCTAssertEqual(unavailable.actionDescription?.kind, .unsupported)
        XCTAssertEqual(unavailable.actionDescription?.target, "missing session")
    }

    func testExecuteModeUsesInjectedRunnerSuccess() {
        let runner = RecordingJumpRunner(result: .succeeded("runner opened workspace"))
        let input = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "workspace",
                precision: .workspace,
                diagnosticSummary: "workspace: workspace",
                resolvedTarget: TerminalResolver().resolve(input)
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .executed)
        XCTAssertNil(result.blockReason)
        XCTAssertEqual(result.diagnosticSummary, "runner opened workspace")
        XCTAssertEqual(runner.actions, [
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "workspace"
            )
        ])
    }

    func testExecuteModePassesWorkspaceHandlerIdToRunner() {
        let runner = RecordingJumpRunner(result: .succeeded("runner success"))
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "workspace",
                precision: .workspace,
                diagnosticSummary: "workspace: workspace",
                resolvedTarget: TerminalResolver().resolve(JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project"))
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(runner.actions.first?.handlerId, "workspace")
        XCTAssertEqual(result.actionDescription?.handlerId, "workspace")
    }

    func testExecuteModePassesIDEWorkspaceHandlerIdToRunner() {
        let runner = RecordingJumpRunner(result: .succeeded("runner success"))
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "ide-workspace",
                precision: .workspace,
                diagnosticSummary: "ide-workspace: workspace",
                resolvedTarget: TerminalResolver().resolve(JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project", isIDEHost: true))
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(runner.actions.first?.handlerId, "ide-workspace")
        XCTAssertEqual(result.actionDescription?.handlerId, "ide-workspace")
    }

    func testExecuteModePassesPerIDEWorkspaceDescriptorToRunner() {
        let runner = RecordingJumpRunner(result: .succeeded("runner success"))
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "cursor-workspace",
                precision: .workspace,
                diagnosticSummary: "cursor-workspace: workspace",
                resolvedTarget: TerminalResolver().resolve(JumpInput(
                    sessionId: "s1",
                    source: "codex",
                    bundleId: "com.todesktop.230313mzl4w4u92",
                    cwd: "/tmp/project"
                ))
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(runner.actions.first?.kind, .openWorkspace)
        XCTAssertEqual(runner.actions.first?.target, "/tmp/project")
        XCTAssertEqual(runner.actions.first?.handlerId, "cursor-workspace")
        XCTAssertEqual(result.actionDescription?.handlerId, "cursor-workspace")
    }

    func testExecuteModeUsesInjectedRunnerFailure() {
        let runner = RecordingJumpRunner(result: .failed(.dependencyMissing, diagnosticSummary: "workspace opener missing"))
        let input = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: "s1",
                status: .planned,
                handlerId: "workspace",
                precision: .workspace,
                diagnosticSummary: "workspace: workspace",
                resolvedTarget: TerminalResolver().resolve(input)
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertEqual(result.diagnosticSummary, "workspace opener missing")
        XCTAssertEqual(runner.actions.count, 1)
    }

    func testTerminalTmuxPaneWithoutAttachedClientBlocksInsteadOfReportingJumpSuccess() {
        let runner = RecordingJumpRunner(result: .failed(
            .executionFailed,
            diagnosticSummary: "Terminal tab not found for tmux client"
        ))
        let input = JumpInput(
            sessionId: "detached-hermes-session",
            source: "hermes",
            bundleId: "com.apple.Terminal",
            tmuxPane: "%1",
            tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency"
        )
        let result = TerminalJumpExecutor(runner: runner).execute(
            plan: JumpActionPlan(
                sessionId: input.sessionId,
                status: .planned,
                handlerId: "tmux",
                precision: .exactPane,
                diagnosticSummary: "tmux: exact",
                resolvedTarget: TerminalResolver().resolve(input)
            ),
            mode: .execute
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.diagnosticSummary, "Terminal tab not found for tmux client")
        XCTAssertEqual(runner.actions.count, 1)
        XCTAssertEqual(runner.actions.first?.kind, .runAutomation)
        XCTAssertEqual(runner.actions.first?.target, "com.apple.Terminal")
        XCTAssertTrue(runner.actions.first?.arguments.contains("if not focusedTab then error \"Terminal tab not found for tmux client\"") == true)
    }

    func testDryRunDoesNotCallInjectedRunner() {
        let runner = RecordingJumpRunner(result: .succeeded("should not run"))
        let result = TerminalJumpExecutor(runner: runner).execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            handlerId: "tmux",
            precision: .exactPane,
            diagnosticSummary: "tmux: exactPane"
        ))

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(runner.actions, [])
    }

    func testRepairUnavailableAndPreblockedPlansDoNotCallRunner() {
        let runner = RecordingJumpRunner(result: .succeeded("should not run"))
        let executor = TerminalJumpExecutor(runner: runner)

        _ = executor.execute(plan: JumpActionPlan(
            sessionId: "remote",
            status: .repairRequired,
            handlerId: "remote-hint",
            precision: .remoteHint,
            repairAction: "Reconnect remote terminal before jumping",
            diagnosticSummary: "remote-hint: remoteRequiresReconnect"
        ), mode: .execute)
        _ = executor.execute(plan: JumpActionPlan(
            sessionId: "missing",
            status: .unavailable,
            failureReason: .missingSession,
            diagnosticSummary: "missing session"
        ), mode: .execute)
        _ = executor.execute(plan: JumpActionPlan(
            sessionId: "s1",
            status: .planned,
            precision: .exactPane,
            diagnosticSummary: "missing handler"
        ), mode: .execute)

        XCTAssertEqual(runner.actions, [])
    }
}
