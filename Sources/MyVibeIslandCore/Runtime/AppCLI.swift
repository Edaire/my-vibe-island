import Foundation

public struct AppCLI {
    private let runtimeFactory: () -> AppRuntime
    private let modeResolver: AppExecutableModeResolver

    public init(
        runtimeFactory: @escaping () -> AppRuntime = { AppRuntime.productionRuntime() },
        modeResolver: AppExecutableModeResolver = AppExecutableModeResolver(defaultMode: .cli)
    ) {
        self.runtimeFactory = runtimeFactory
        self.modeResolver = modeResolver
    }

    public func run(arguments: [String]) throws -> String {
        let resolution = modeResolver.resolve(arguments: arguments)
        switch resolution.mode {
        case .cli:
            return runCLI(arguments: resolution.remainingArguments)
        case .appShell:
            return appShellOutput(arguments: resolution.remainingArguments)
        case .help:
            return helpOutput()
        case .invalid:
            return resolution.diagnostic ?? "invalid top-level arguments"
        }
    }

    private func runCLI(arguments: [String]) -> String {
        if arguments.contains("--bridge-smoke") {
            return bridgeSmokeOutput(arguments: arguments)
        }

        guard let command = arguments.first else {
            return defaultOutput()
        }

        switch command {
        case "status":
            return runtimeBackedOutput(arguments: arguments) { runtime in
                statusOutput(runtime.status())
            }
        case "sync-opencode":
            return syncOpenCodeOutput(arguments: arguments)
        case "jump":
            return jumpOutput(arguments: arguments)
        default:
            return defaultOutput()
        }
    }

    private func helpOutput() -> String {
        [
            "My Vibe Island",
            "Usage:",
            "  my-vibe-island --app        Start the app shell",
            "  my-vibe-island status       Print runtime status",
            "  my-vibe-island jump         Print or execute a session jump",
            "  my-vibe-island sync-opencode --root <path>",
        ].joined(separator: "\n")
    }

    private func appShellOutput(arguments: [String]) -> String {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        let summary = launchPlan.summary
        let platformSummary = AppShellPlatformLaunchPlanner()
            .makePlan(from: launchPlan)
            .summary
        var lines = [
            "My Vibe Island app shell",
            "launch plan: dry run",
            "target: \(summary.targetDisplayName)",
            "route: \(summary.route.rawValue)",
            "runtime starts: \(summary.runtimeOwnerStartCount)",
            "actions: \(summary.actionCount)",
            "status menu entries: \(summary.statusItemMenuEntryCount)",
            "closed frame: \(displayFrameOutput(summary.closedFrame))",
            "platform intents: \(platformSummary.intentCount)",
            "lifecycle intents: \(platformSummary.lifecycleIntentCount)",
            "runtime start intents: \(platformSummary.runtimeStartIntentCount)",
            "notch window intents: \(platformSummary.notchWindowIntentCount)",
            "route intents: \(platformSummary.routeIntentCount)",
            "platform intent plan: \(platformSummary.intentGroupDescription)",
            "platform launch: not wired",
        ]
        if !arguments.isEmpty {
            lines.append("arguments: \(arguments.joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }

    private func displayFrameOutput(_ frame: DisplayFrame) -> String {
        "\(numberOutput(frame.x)),\(numberOutput(frame.y)) \(numberOutput(frame.width))x\(numberOutput(frame.height))"
    }

    private func numberOutput(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private func defaultOutput() -> String {
        [
            "My Vibe Island starting: runnable skeleton",
            "Bridge socket: \(BridgeSocketPath.defaultPath())",
        ].joined(separator: "\n")
    }

    private func statusOutput(_ status: AppRuntimeStatus) -> String {
        var lines = [
            "My Vibe Island runtime status",
            "bridge: \(status.isBridgeRunning ? "running" : "stopped")",
            "sessions: \(status.sessionCount)",
        ]

        if let diagnostics = status.openCodeSyncDiagnostics {
            lines.append(contentsOf: openCodeSyncLines(diagnostics))
        } else {
            lines.append("opencode sync: not run")
        }

        return lines.joined(separator: "\n")
    }

    private func openCodeSyncLines(_ diagnostics: OpenCodeSyncDiagnostics) -> [String] {
        [
            "root: \(diagnostics.rootPath)",
            "attempted: \(diagnostics.attemptedFileCount)",
            "successful: \(diagnostics.successfulSnapshotCount)",
            "failed: \(diagnostics.failedSnapshotCount)",
            "events: \(diagnostics.emittedEventCount)",
            "root missing: \(diagnostics.rootMissing)",
        ]
    }

    private func syncOpenCodeOutput(arguments: [String]) -> String {
        guard let rootPath = value(after: "--root", in: arguments) else {
            return "Missing --root for OpenCode sync"
        }

        return runtimeBackedOutput(arguments: arguments) { runtime in
            runtime.syncOpenCodeDiskSessions(rootURL: URL(fileURLWithPath: rootPath, isDirectory: true))
            guard let diagnostics = runtime.status().openCodeSyncDiagnostics else {
                return "My Vibe Island OpenCode sync\nopencode sync: not run"
            }

            return (
                ["My Vibe Island OpenCode sync"]
                    + openCodeSyncLines(diagnostics)
                    + syncedSessionLines(runtime.runtimeSessionSnapshots())
            ).joined(separator: "\n")
        }
    }

    private func syncedSessionLines(_ snapshots: [RuntimeSessionSnapshot]) -> [String] {
        guard !snapshots.isEmpty else {
            return ["synced sessions: none"]
        }

        return ["synced sessions:"] + snapshots.map {
            "- \($0.snapshot.source): \($0.snapshot.sessionId)"
        }
    }

    private func jumpOutput(arguments: [String]) -> String {
        guard let sessionId = value(after: "--session", in: arguments) else {
            return "Missing --session for jump"
        }

        return runtimeBackedOutput(arguments: arguments) { runtime in
            if arguments.contains("--execute") {
                return jumpExecutionOutput(
                    runtime.executeJumpToSession(sessionId: sessionId, mode: .execute),
                    title: "My Vibe Island jump execute"
                )
            }
            if arguments.contains("--dry-run") {
                return jumpExecutionOutput(
                    runtime.executeJumpToSession(sessionId: sessionId, mode: .dryRun),
                    title: "My Vibe Island jump dry run"
                )
            }

            return jumpPlanOutput(runtime.jumpToSession(sessionId: sessionId))
        }
    }

    private func runtime(arguments: [String]) -> AppRuntime? {
        guard let homePath = value(after: "--home", in: arguments) else {
            if arguments.contains("--home") {
                return nil
            }
            return runtimeFactory()
        }

        return AppRuntime.productionRuntime(homeDirectory: URL(fileURLWithPath: homePath, isDirectory: true))
    }

    private func runtimeBackedOutput(
        arguments: [String],
        produce: (AppRuntime) -> String
    ) -> String {
        guard let runtime = runtime(arguments: arguments) else {
            return "Missing --home value"
        }
        return produce(runtime)
    }

    private func jumpPlanOutput(_ plan: JumpActionPlan) -> String {
        var lines = [
            "My Vibe Island jump plan",
            "session: \(plan.sessionId)",
            "status: \(plan.status.rawValue)",
        ]

        if let handlerId = plan.handlerId {
            lines.append("handler: \(handlerId)")
        }
        if let precision = plan.precision {
            lines.append("precision: \(precision.rawValue)")
        }
        if let failureReason = plan.failureReason {
            lines.append("failure: \(failureReason.rawValue)")
        }
        if let repairAction = plan.repairAction {
            lines.append("repair: \(repairAction)")
        }
        lines.append("diagnostic: \(plan.diagnosticSummary)")
        return lines.joined(separator: "\n")
    }

    private func jumpExecutionOutput(
        _ result: TerminalJumpExecutionResult,
        title: String
    ) -> String {
        var lines = [
            title,
            "session: \(result.sessionId)",
            "status: \(result.status.rawValue)",
        ]

        if let handlerId = result.handlerId {
            lines.append("handler: \(handlerId)")
        }
        if let precision = result.precision {
            lines.append("precision: \(precision.rawValue)")
        }
        lines.append("permissions: \(permissionRequirementsOutput(result.permissionRequirements))")
        if let actionDescription = result.actionDescription {
            lines.append("action: \(actionDescription.kind.rawValue)")
            if let target = actionDescription.target {
                lines.append("target: \(target)")
            }
        }
        if let blockReason = result.blockReason {
            lines.append("block: \(blockReason.rawValue)")
        }
        if let repairAction = result.repairAction {
            lines.append("repair: \(repairAction)")
        }
        lines.append("diagnostic: \(result.diagnosticSummary)")
        return lines.joined(separator: "\n")
    }

    private func permissionRequirementsOutput(_ requirements: [TerminalPermissionRequirement]) -> String {
        guard !requirements.isEmpty else {
            return "none"
        }

        return requirements.map(\.rawValue).joined(separator: ",")
    }

    private func bridgeSmokeOutput(arguments: [String]) -> String {
        guard let socketPath = value(after: "--socket", in: arguments) else {
            return "Missing --socket for bridge smoke"
        }

        let runtime = AppRuntimeSessionStore.runtime(socketPath: socketPath)
        do {
            try runtime.startBridge()
            defer {
                runtime.stop()
            }

            let response = try BridgeClient(socketPath: socketPath).send(
                BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "diagnostic",
                    source: "app",
                    requestId: nil,
                    command: .hello,
                    payload: [:]
                )
            )
            return "Bridge smoke: \(response.message ?? "unknown")"
        } catch {
            return "Bridge smoke failed: \(error)"
        }
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            return nil
        }

        return value
    }
}
