import AppKit
import Darwin
import Foundation

public enum TerminalJumpActionKind: String, Codable, Equatable, Sendable {
    case openURL
    case openWorkspace
    case activateApplication
    case runCLI
    case sendSocketRequest
    case runAutomation
    case showRepair
    case unsupported
}

public struct TerminalJumpActionDescription: Codable, Equatable, Sendable {
    public let kind: TerminalJumpActionKind
    public let summary: String
    public let target: String?
    public let handlerId: String?
    public let arguments: [String]

    public init(
        kind: TerminalJumpActionKind,
        summary: String,
        target: String? = nil,
        handlerId: String? = nil,
        arguments: [String] = []
    ) {
        self.kind = kind
        self.summary = summary
        self.target = target
        self.handlerId = handlerId
        self.arguments = arguments
    }
}

public protocol TerminalJumpActionRunning: Sendable {
    func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult
}

public enum TerminalJumpRunnerStatus: String, Codable, Equatable, Sendable {
    case succeeded
    case failed
}

public enum TerminalJumpRunnerFailureReason: String, Codable, Equatable, Sendable {
    case unsupportedAction
    case missingTarget
    case permissionDenied
    case dependencyMissing
    case executionFailed
}

public struct TerminalJumpRunnerResult: Codable, Equatable, Sendable {
    public let status: TerminalJumpRunnerStatus
    public let failureReason: TerminalJumpRunnerFailureReason?
    public let diagnosticSummary: String

    public init(
        status: TerminalJumpRunnerStatus,
        failureReason: TerminalJumpRunnerFailureReason? = nil,
        diagnosticSummary: String
    ) {
        self.status = status
        self.failureReason = failureReason
        self.diagnosticSummary = diagnosticSummary
    }

    public static func succeeded(_ diagnosticSummary: String) -> TerminalJumpRunnerResult {
        TerminalJumpRunnerResult(status: .succeeded, diagnosticSummary: diagnosticSummary)
    }

    public static func failed(
        _ failureReason: TerminalJumpRunnerFailureReason,
        diagnosticSummary: String
    ) -> TerminalJumpRunnerResult {
        TerminalJumpRunnerResult(status: .failed, failureReason: failureReason, diagnosticSummary: diagnosticSummary)
    }
}

public struct TerminalJumpActionRunner: TerminalJumpActionRunning {
    private let workspaceRunner: TerminalJumpActionRunning
    private let cliRunner: TerminalJumpActionRunning
    private let socketRunner: TerminalJumpActionRunning
    private let urlRunner: TerminalJumpActionRunning
    private let applicationRunner: TerminalJumpActionRunning
    private let automationRunner: TerminalJumpActionRunning

    public init(
        workspaceRunner: TerminalJumpActionRunning,
        cliRunner: TerminalJumpActionRunning,
        socketRunner: TerminalJumpActionRunning,
        urlRunner: TerminalJumpActionRunning,
        applicationRunner: TerminalJumpActionRunning,
        automationRunner: TerminalJumpActionRunning
    ) {
        self.workspaceRunner = workspaceRunner
        self.cliRunner = cliRunner
        self.socketRunner = socketRunner
        self.urlRunner = urlRunner
        self.applicationRunner = applicationRunner
        self.automationRunner = automationRunner
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        switch action.kind {
        case .openURL:
            return urlRunner.run(action)
        case .activateApplication:
            return applicationRunner.run(action)
        case .runAutomation:
            return automationRunner.run(action)
        case .openWorkspace:
            return workspaceRunner.run(action)
        case .runCLI:
            return cliRunner.run(action)
        case .sendSocketRequest:
            return socketRunner.run(action)
        default:
            return .failed(
                .unsupportedAction,
                diagnosticSummary: "terminal action runner unsupported action: \(action.kind.rawValue)"
            )
        }
    }
}

public struct CLIActionRunner: TerminalJumpActionRunning {
    private let commandResolver: @Sendable (String) -> String?
    private let launch: @Sendable (String, [String]) -> Bool

    public init(
        commandResolver: @escaping @Sendable (String) -> String? = SystemCLICommandResolver().executablePath,
        launch: @escaping @Sendable (String, [String]) -> Bool = SystemCLICommandLauncher().launch
    ) {
        self.commandResolver = commandResolver
        self.launch = launch
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .runCLI else {
            return .failed(.unsupportedAction, diagnosticSummary: "cli runner unsupported action: \(action.kind.rawValue)")
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "cli runner missing target")
        }

        guard let commandPath = commandResolver(target) else {
            return .failed(.dependencyMissing, diagnosticSummary: "missing CLI command: \(target)")
        }

        guard launch(commandPath, action.arguments) else {
            return .failed(.executionFailed, diagnosticSummary: "failed to run CLI handler \(target)")
        }

        return .succeeded("ran CLI handler \(target)")
    }
}

public struct SystemUnixSocketSender: Sendable {
    private let transport: @Sendable (String, Data) -> Bool

    public init() {
        transport = Self.write
    }

    public init(transport: @escaping @Sendable (String, Data) -> Bool) {
        self.transport = transport
    }

    public func send(target: String, arguments: [String]) -> Bool {
        guard target == "cmux",
              arguments.count == 4,
              arguments[0] == "--socket",
              arguments[2] == "surface.focus",
              arguments[1].hasPrefix("/"),
              !arguments[1].contains("\0"),
              !arguments[3].isEmpty,
              arguments[1].utf8.count < MemoryLayout<sockaddr_un>.size - 2 else {
            return false
        }

        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "surface.focus",
            "params": ["surface_id": arguments[3]],
            "id": 1,
        ]
        guard var payload = try? JSONSerialization.data(withJSONObject: object) else {
            return false
        }
        payload.append(0x0A)
        return transport(arguments[1], payload)
    }

    private static func write(path: String, payload: Data) -> Bool {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var noSignal: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        var timeout = timeval(tv_sec: 0, tv_usec: 250_000)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = path.utf8CString
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            for (index, byte) in bytes.enumerated() {
                destination[index] = UInt8(bitPattern: byte)
            }
        }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return false }

        return payload.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return false }
            var written = 0
            while written < rawBuffer.count {
                let count = Darwin.send(descriptor, base.advanced(by: written), rawBuffer.count - written, 0)
                guard count > 0 else { return false }
                written += count
            }
            return true
        }
    }
}

public struct SocketActionRunner: TerminalJumpActionRunning {
    private let send: @Sendable (String, [String]) -> Bool

    public init(
        send: @escaping @Sendable (String, [String]) -> Bool = SystemUnixSocketSender().send
    ) {
        self.send = send
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .sendSocketRequest else {
            return .failed(.unsupportedAction, diagnosticSummary: "socket runner unsupported action: \(action.kind.rawValue)")
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "socket runner missing target")
        }

        guard !action.arguments.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "socket runner missing arguments for \(target)")
        }

        guard send(target, action.arguments) else {
            return .failed(.executionFailed, diagnosticSummary: "failed to send socket request for \(target)")
        }

        return .succeeded("sent socket request for \(target)")
    }
}

public struct URLActionRunner: TerminalJumpActionRunning {
    private let canOpen: @Sendable (URL) -> Bool
    private let open: @Sendable (URL) -> Bool

    public init(
        canOpen: @escaping @Sendable (URL) -> Bool = { _ in true },
        open: @escaping @Sendable (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.canOpen = canOpen
        self.open = open
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .openURL else {
            return .failed(.unsupportedAction, diagnosticSummary: "URL runner unsupported action: \(action.kind.rawValue)")
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "URL runner missing target")
        }

        guard let url = URL(string: target), let scheme = url.scheme, !scheme.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "URL runner invalid URL: \(target)")
        }

        guard canOpen(url) else {
            return .failed(.dependencyMissing, diagnosticSummary: "missing URL scheme handler: \(scheme)")
        }

        guard open(url) else {
            return .failed(.executionFailed, diagnosticSummary: "failed to open URL: \(target)")
        }

        return .succeeded("opened URL: \(target)")
    }
}

public struct SystemURLSchemeAvailability: Sendable {
    public init() {}

    public func canOpen(url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}

public struct ApplicationActionRunner: TerminalJumpActionRunning {
    private let activate: @Sendable (String) -> Bool

    public init(
        activate: @escaping @Sendable (String) -> Bool = SystemApplicationActivator().activate
    ) {
        self.activate = activate
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .activateApplication else {
            return .failed(.unsupportedAction, diagnosticSummary: "application runner unsupported action: \(action.kind.rawValue)")
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "application runner missing target")
        }

        guard activate(target) else {
            return .failed(.executionFailed, diagnosticSummary: "failed to activate application: \(target)")
        }

        return .succeeded("activated application: \(target)")
    }
}

public enum AutomationRunResult: Equatable, Sendable {
    case succeeded
    case permissionDenied
    case failed
}

public struct AutomationActionRunner: TerminalJumpActionRunning {
    private let runAutomation: @Sendable (String, [String]) -> AutomationRunResult

    public init(
        runAutomation: @escaping @Sendable (String, [String]) -> AutomationRunResult = SystemAutomationRunner().run
    ) {
        self.runAutomation = runAutomation
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .runAutomation else {
            return .failed(.unsupportedAction, diagnosticSummary: "automation runner unsupported action: \(action.kind.rawValue)")
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "automation runner missing target")
        }

        switch runAutomation(target, action.arguments) {
        case .succeeded:
            return .succeeded("ran automation for \(target)")
        case .permissionDenied:
            return .failed(.permissionDenied, diagnosticSummary: "automation permission denied for \(target)")
        case .failed:
            return .failed(.executionFailed, diagnosticSummary: "failed to run automation for \(target)")
        }
    }
}

public struct SystemAutomationRunner: Sendable {
    private let launch: @Sendable ([String]) -> AutomationRunResult

    public init(
        launch: @escaping @Sendable ([String]) -> AutomationRunResult = SystemAutomationProcessLauncher().launch
    ) {
        self.launch = launch
    }

    public func run(target: String, arguments: [String]) -> AutomationRunResult {
        guard !target.isEmpty, !arguments.isEmpty else {
            return .failed
        }

        let osascriptArguments = arguments.flatMap { ["-e", $0] }
        return launch(osascriptArguments)
    }
}

public struct AutomationProcessResult: Equatable, Sendable {
    public let terminationStatus: Int32
    public let standardError: String

    public init(terminationStatus: Int32, standardError: String) {
        self.terminationStatus = terminationStatus
        self.standardError = standardError
    }
}

public struct SystemAutomationProcessLauncher: Sendable {
    private let execute: @Sendable ([String]) throws -> AutomationProcessResult

    public init() {
        self.execute = SystemAutomationProcessLauncher.executeProcess
    }

    public init(_ execute: @escaping @Sendable ([String]) throws -> AutomationProcessResult) {
        self.execute = execute
    }

    public func launch(arguments: [String]) -> AutomationRunResult {
        do {
            let result = try execute(arguments)
            guard result.terminationStatus == 0 else {
                return isPermissionDenied(standardError: result.standardError) ? .permissionDenied : .failed
            }
            return .succeeded
        } catch {
            return .failed
        }
    }

    private static func executeProcess(arguments: [String]) throws -> AutomationProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = arguments
        process.standardOutput = Pipe()
        let standardError = Pipe()
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let standardErrorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let standardErrorText = String(data: standardErrorData, encoding: .utf8) ?? ""
        return AutomationProcessResult(terminationStatus: process.terminationStatus, standardError: standardErrorText)
    }

    private func isPermissionDenied(standardError: String) -> Bool {
        let markers = [
            "not authorized to send Apple events",
            "Not authorized to send Apple events",
            "(-1743)",
            "errAEEventNotPermitted"
        ]
        return markers.contains { standardError.contains($0) }
    }
}

public struct SystemApplicationActivator: Sendable {
    public init() {}

    public func activate(bundleId: String) -> Bool {
        if let runningApplication = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            return runningApplication.activate(options: [])
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return false
        }

        let semaphore = DispatchSemaphore(value: 0)
        let result = ApplicationActivationResultBox()
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: NSWorkspace.OpenConfiguration()) { application, error in
            result.set(application != nil && error == nil)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return result.value
    }
}

private final class ApplicationActivationResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result = false

    var value: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return result
    }

    func set(_ result: Bool) {
        lock.lock()
        self.result = result
        lock.unlock()
    }
}

public struct SystemCLICommandResolver: Sendable {
    private let environment: [String: String]
    private let isExecutableFile: @Sendable (String) -> Bool

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.environment = environment
        self.isExecutableFile = isExecutableFile
    }

    public func executablePath(for command: String) -> String? {
        if command.contains("/") {
            return isExecutableFile(command) ? command : nil
        }

        return environment["PATH"]?
            .split(separator: ":")
            .map(String.init)
            .map { "\($0)/\(command)" }
            .first(where: isExecutableFile)
    }
}

public struct SystemCLICommandLauncher: Sendable {
    public init() {}

    public func launch(commandPath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

public enum TerminalJumpExecutionMode: String, Codable, Equatable, Sendable {
    case dryRun
    case execute
}

public enum TerminalJumpExecutionStatus: String, Codable, Equatable, Sendable {
    case dryRun
    case executed
    case blocked
    case repairRequired
    case unavailable
}

public enum TerminalJumpExecutionBlockReason: String, Codable, Equatable, Sendable {
    case executionNotImplemented
    case missingHandler
    case unsupportedHandler
    case requiresRepair
    case unavailablePlan
    case runnerFailed
}

public struct TerminalJumpExecutionResult: Codable, Equatable, Sendable {
    public let sessionId: String
    public let status: TerminalJumpExecutionStatus
    public let handlerId: String?
    public let precision: JumpPrecision?
    public let permissionRequirements: [TerminalPermissionRequirement]
    public let blockReason: TerminalJumpExecutionBlockReason?
    public let repairAction: String?
    public let diagnosticSummary: String
    public let actionDescription: TerminalJumpActionDescription?

    public init(
        sessionId: String,
        status: TerminalJumpExecutionStatus,
        handlerId: String? = nil,
        precision: JumpPrecision? = nil,
        permissionRequirements: [TerminalPermissionRequirement] = [],
        blockReason: TerminalJumpExecutionBlockReason? = nil,
        repairAction: String? = nil,
        diagnosticSummary: String,
        actionDescription: TerminalJumpActionDescription? = nil
    ) {
        self.sessionId = sessionId
        self.status = status
        self.handlerId = handlerId
        self.precision = precision
        self.permissionRequirements = permissionRequirements
        self.blockReason = blockReason
        self.repairAction = repairAction
        self.diagnosticSummary = diagnosticSummary
        self.actionDescription = actionDescription
    }
}

public struct TerminalJumpExecutor: Sendable {
    private let registry: TerminalRegistry
    private let runner: TerminalJumpActionRunning?

    public init(registry: TerminalRegistry = .default, runner: TerminalJumpActionRunning? = nil) {
        self.registry = registry
        self.runner = runner
    }

    public func execute(
        plan: JumpActionPlan,
        mode: TerminalJumpExecutionMode = .dryRun
    ) -> TerminalJumpExecutionResult {
        if plan.status == .unavailable {
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .unavailable,
                handlerId: plan.handlerId,
                precision: plan.precision,
                blockReason: .unavailablePlan,
                repairAction: plan.repairAction,
                diagnosticSummary: plan.diagnosticSummary,
                actionDescription: actionDescription(for: plan)
            )
        }

        if plan.status == .repairRequired {
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .repairRequired,
                handlerId: plan.handlerId,
                precision: plan.precision,
                permissionRequirements: descriptor(for: plan.handlerId)?.permissionRequirements ?? [],
                blockReason: .requiresRepair,
                repairAction: plan.repairAction,
                diagnosticSummary: plan.diagnosticSummary,
                actionDescription: actionDescription(for: plan)
            )
        }

        guard let handlerId = plan.handlerId else {
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .blocked,
                precision: plan.precision,
                blockReason: .missingHandler,
                repairAction: plan.repairAction,
                diagnosticSummary: plan.diagnosticSummary,
                actionDescription: actionDescription(for: plan)
            )
        }

        guard let descriptor = descriptor(for: handlerId) else {
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .blocked,
                handlerId: handlerId,
                precision: plan.precision,
                blockReason: .unsupportedHandler,
                repairAction: plan.repairAction,
                diagnosticSummary: plan.diagnosticSummary,
                actionDescription: actionDescription(for: plan)
            )
        }

        guard let precision = plan.precision, descriptor.supportedPrecisions.contains(precision) else {
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .blocked,
                handlerId: handlerId,
                precision: plan.precision,
                permissionRequirements: descriptor.permissionRequirements,
                blockReason: .unsupportedHandler,
                repairAction: plan.repairAction,
                diagnosticSummary: plan.diagnosticSummary,
                actionDescription: actionDescription(for: plan)
            )
        }

        switch mode {
        case .dryRun:
            return TerminalJumpExecutionResult(
                sessionId: plan.sessionId,
                status: .dryRun,
                handlerId: handlerId,
                precision: precision,
                permissionRequirements: descriptor.permissionRequirements,
                diagnosticSummary: "dry run: \(handlerId) \(precision.rawValue)",
                actionDescription: actionDescription(for: plan)
            )
        case .execute:
            let actionDescription = actionDescription(for: plan)
            guard let runner else {
                return TerminalJumpExecutionResult(
                    sessionId: plan.sessionId,
                    status: .blocked,
                    handlerId: handlerId,
                    precision: precision,
                    permissionRequirements: descriptor.permissionRequirements,
                    blockReason: .executionNotImplemented,
                    repairAction: plan.repairAction,
                    diagnosticSummary: "execution not implemented: \(handlerId)",
                    actionDescription: actionDescription
                )
            }

            let runnerResult = runner.run(actionDescription)
            switch runnerResult.status {
            case .succeeded:
                return TerminalJumpExecutionResult(
                    sessionId: plan.sessionId,
                    status: .executed,
                    handlerId: handlerId,
                    precision: precision,
                    permissionRequirements: descriptor.permissionRequirements,
                    repairAction: plan.repairAction,
                    diagnosticSummary: runnerResult.diagnosticSummary,
                    actionDescription: actionDescription
                )
            case .failed:
                return TerminalJumpExecutionResult(
                    sessionId: plan.sessionId,
                    status: .blocked,
                    handlerId: handlerId,
                    precision: precision,
                    permissionRequirements: descriptor.permissionRequirements,
                    blockReason: .runnerFailed,
                    repairAction: plan.repairAction,
                    diagnosticSummary: runnerResult.diagnosticSummary,
                    actionDescription: actionDescription
                )
            }
        }
    }

    private func actionDescription(for plan: JumpActionPlan) -> TerminalJumpActionDescription {
        if plan.status == .repairRequired {
            return TerminalJumpActionDescription(kind: .showRepair, summary: "show repair", target: plan.repairAction)
        }

        if plan.status == .unavailable {
            return TerminalJumpActionDescription(kind: .unsupported, summary: "unsupported", target: plan.diagnosticSummary)
        }

        guard let handlerId = plan.handlerId else {
            return TerminalJumpActionDescription(kind: .unsupported, summary: "unsupported", target: plan.diagnosticSummary)
        }

        let input = plan.resolvedTarget?.input
        switch handlerId {
        case "custom-url":
            return TerminalJumpActionDescription(
                kind: .openURL,
                summary: "open URL",
                target: input?.customJumpURL,
                handlerId: handlerId
            )
        case "codex-deeplink":
            return TerminalJumpActionDescription(
                kind: .openURL,
                summary: "open URL",
                target: input?.codexThreadId.map { "codex://threads/\($0)" },
                handlerId: handlerId
            )
        case "warp":
            return TerminalJumpActionDescription(
                kind: .openURL,
                summary: "open URL",
                target: input?.warpFocusURL,
                handlerId: handlerId
            )
        case "claude-desktop-code":
            return TerminalJumpActionDescription(
                kind: .activateApplication,
                summary: "activate application",
                target: input?.bundleId,
                handlerId: handlerId
            )
        case "workspace", "ide-workspace":
            return TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: input?.cwd,
                handlerId: handlerId
            )
        case "application":
            return TerminalJumpActionDescription(
                kind: .activateApplication,
                summary: "activate application",
                target: applicationBundleIdentifier(from: input),
                handlerId: handlerId
            )
        case "tmux":
            if let arguments = tmuxTerminalAutomationArguments(from: input) {
                return TerminalJumpActionDescription(
                    kind: .runAutomation,
                    summary: "focus tmux pane in Terminal",
                    target: input?.bundleId,
                    handlerId: handlerId,
                    arguments: arguments
                )
            }
            return TerminalJumpActionDescription(
                kind: .runCLI,
                summary: "run CLI handler",
                target: handlerId,
                handlerId: handlerId,
                arguments: tmuxArguments(from: input)
            )
        case "zellij":
            return TerminalJumpActionDescription(
                kind: .runCLI,
                summary: "run CLI handler",
                target: handlerId,
                handlerId: handlerId,
                arguments: zellijArguments(from: input)
            )
        case "wezterm":
            return TerminalJumpActionDescription(
                kind: .runCLI,
                summary: "run CLI handler",
                target: handlerId,
                handlerId: handlerId,
                arguments: wezTermArguments(from: input)
            )
        case "kaku":
            return TerminalJumpActionDescription(
                kind: .runCLI,
                summary: "run CLI handler",
                target: handlerId,
                handlerId: handlerId,
                arguments: kakuArguments(from: input)
            )
        case "kitty":
            return TerminalJumpActionDescription(
                kind: .runCLI,
                summary: "run CLI handler",
                target: handlerId,
                handlerId: handlerId,
                arguments: kittyArguments(from: input)
            )
        case "cmux":
            return TerminalJumpActionDescription(
                kind: .sendSocketRequest,
                summary: "send socket request",
                target: handlerId,
                handlerId: handlerId,
                arguments: cmuxArguments(from: input)
            )
        case "otty":
            return TerminalJumpActionDescription(
                kind: .sendSocketRequest,
                summary: "send socket request",
                target: handlerId,
                handlerId: handlerId,
                arguments: ottyArguments(from: input)
            )
        case "supacode":
            return TerminalJumpActionDescription(
                kind: .sendSocketRequest,
                summary: "send socket request",
                target: handlerId,
                handlerId: handlerId,
                arguments: supacodeArguments(from: input)
            )
        case "ghostty":
            return TerminalJumpActionDescription(
                kind: .runAutomation,
                summary: "run automation",
                target: input?.bundleId ?? "com.mitchellh.ghostty",
                handlerId: handlerId,
                arguments: ghosttyAutomationArguments(from: input)
            )
        case "iterm":
            return TerminalJumpActionDescription(
                kind: .runAutomation,
                summary: "run automation",
                target: input?.bundleId ?? "com.googlecode.iterm2",
                handlerId: handlerId,
                arguments: iTermAutomationArguments(from: input)
            )
        case "terminal-tty":
            return TerminalJumpActionDescription(
                kind: .runAutomation,
                summary: "run automation",
                target: input?.bundleId ?? "com.apple.Terminal",
                handlerId: handlerId,
                arguments: terminalAutomationArguments(from: input)
            )
        default:
            if isIDEWorkspaceHandler(handlerId) {
                return TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: input?.cwd,
                    handlerId: handlerId
                )
            }

            return TerminalJumpActionDescription(
                kind: .unsupported,
                summary: "unsupported",
                target: handlerId,
                handlerId: handlerId
            )
        }
    }

    private func isIDEWorkspaceHandler(_ handlerId: String) -> Bool {
        guard let descriptor = descriptor(for: handlerId) else {
            return false
        }

        return descriptor.category == .ide
            && descriptor.supportedPrecisions.contains(.workspace)
    }

    private func tmuxArguments(from input: JumpInput?) -> [String] {
        guard let pane = input?.tmuxPane else {
            return []
        }

        var arguments: [String] = []
        if let socketPath = input?.tmuxSocketPath {
            arguments.append(contentsOf: ["-S", socketPath])
        }
        arguments.append(contentsOf: ["select-pane", "-t", pane])
        return arguments
    }

    private func tmuxTerminalAutomationArguments(from input: JumpInput?) -> [String]? {
        guard input?.bundleId == "com.apple.Terminal",
              let socketPath = input?.tmuxSocketPath,
              let pane = input?.tmuxPane else {
            return nil
        }

        return [
            "set tmuxSocketPath to \(appleScriptStringLiteral(socketPath))",
            "set targetPane to \(appleScriptStringLiteral(pane))",
            "set tmuxCommand to do shell script \"for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do if [ -x \\\"$candidate\\\" ]; then printf '%s' \\\"$candidate\\\"; exit 0; fi; done; command -v tmux\"",
            "set targetSession to do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" display-message -p -t \" & quoted form of targetPane & \" '#{session_name}'\"",
            "set clientTTY to do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" list-clients -F '#{client_tty} #{client_session}' | /usr/bin/awk -v session=\" & quoted form of targetSession & \" '$2 == session { print $1; exit }'\"",
            "tell application id \(appleScriptStringLiteral("com.apple.Terminal"))",
            "activate",
            "set focusedTab to false",
            "repeat with candidateWindow in windows",
            "if not focusedTab then",
            "repeat with candidateTab in tabs of candidateWindow",
            "if tty of candidateTab is clientTTY then",
            "set selected tab of candidateWindow to candidateTab",
            "set index of candidateWindow to 1",
            "set focusedTab to true",
            "exit repeat",
            "end if",
            "end repeat",
            "end if",
            "end repeat",
            "if not focusedTab then error \"Terminal tab not found for tmux client\"",
            "end tell",
            "do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" switch-client -c \" & quoted form of clientTTY & \" -t \" & quoted form of targetSession",
            "do shell script quoted form of tmuxCommand & \" -S \" & quoted form of tmuxSocketPath & \" select-pane -t \" & quoted form of targetPane",
        ]
    }

    private func zellijArguments(from input: JumpInput?) -> [String] {
        guard let paneId = input?.zellijPaneId else {
            return []
        }

        var arguments: [String] = []
        if let sessionName = input?.zellijSessionName {
            arguments.append(contentsOf: ["--session", sessionName])
        }
        arguments.append(contentsOf: ["action", "focus-pane", paneId])
        return arguments
    }

    private func wezTermArguments(from input: JumpInput?) -> [String] {
        guard let pane = input?.weztermPane else {
            return []
        }

        var arguments = ["cli"]
        if let socket = input?.weztermSocket {
            arguments.append(contentsOf: ["--socket", socket])
        }
        arguments.append(contentsOf: ["activate-pane", "--pane-id", pane])
        return arguments
    }

    private func kakuArguments(from input: JumpInput?) -> [String] {
        wezTermArguments(from: input)
    }

    private func kittyArguments(from input: JumpInput?) -> [String] {
        guard let listenOn = input?.kittyListenOn, let windowId = input?.kittyWindowId else {
            return []
        }

        return [
            "@",
            "--to",
            listenOn,
            "focus-window",
            "--match",
            "id:\(windowId)"
        ]
    }

    private func cmuxArguments(from input: JumpInput?) -> [String] {
        guard let socketPath = input?.cmuxSocketPath, let surfaceId = input?.cmuxSurfaceId else {
            return []
        }

        return [
            "--socket",
            socketPath,
            "surface.focus",
            surfaceId
        ]
    }

    private func ottyArguments(from input: JumpInput?) -> [String] {
        guard let socket = input?.ottySocket, let paneId = input?.ottyPaneId else {
            return []
        }

        return [
            "--socket",
            socket,
            "focus-pane",
            paneId
        ]
    }

    private func supacodeArguments(from input: JumpInput?) -> [String] {
        guard let socketPath = input?.supacodeSocketPath else {
            return []
        }

        if let surfaceId = input?.supacodeSurfaceId {
            return ["--socket", socketPath, "surface.focus", surfaceId]
        }
        if let tabId = input?.supacodeTabId {
            return ["--socket", socketPath, "tab.focus", tabId]
        }
        if let worktreeId = input?.supacodeWorktreeId {
            return ["--socket", socketPath, "worktree.focus", worktreeId]
        }
        return []
    }

    private func applicationBundleIdentifier(from input: JumpInput?) -> String? {
        if let bundleId = input?.bundleId {
            return bundleId
        }
        if input?.warpPaneUUID != nil {
            return "dev.warp.Warp-Stable"
        }
        return nil
    }

    private func ghosttyAutomationArguments(from input: JumpInput?) -> [String] {
        let bundleId = input?.bundleId ?? "com.mitchellh.ghostty"
        guard let termSessionId = input?.termSessionId else {
            return [
                "tell application id \(appleScriptStringLiteral(bundleId))",
                "activate",
                "end tell"
            ]
        }

        return [
            "tell application id \(appleScriptStringLiteral(bundleId))",
            "activate",
            "repeat with candidateWindow in windows",
            "set candidateWindowId to id of candidateWindow as text",
            "set candidateWindowName to name of candidateWindow as text",
            "if candidateWindowId is \(appleScriptStringLiteral(termSessionId)) or candidateWindowName is \(appleScriptStringLiteral(termSessionId)) then",
            "set index of candidateWindow to 1",
            "return",
            "end if",
            "end repeat",
            "error \(appleScriptStringLiteral("Ghostty window not found for session \(termSessionId)"))",
            "end tell"
        ]
    }

    private func terminalAutomationArguments(from input: JumpInput?) -> [String] {
        let bundleId = input?.bundleId ?? "com.apple.Terminal"
        guard let tty = input?.tty else {
            return [
                "tell application id \(appleScriptStringLiteral(bundleId))",
                "activate",
                "end tell"
            ]
        }

        return [
            "tell application id \(appleScriptStringLiteral(bundleId))",
            "activate",
            "repeat with candidateWindow in windows",
            "repeat with candidateTab in tabs of candidateWindow",
            "if tty of candidateTab is \(appleScriptStringLiteral(tty)) then",
            "set selected tab of candidateWindow to candidateTab",
            "set index of candidateWindow to 1",
            "return",
            "end if",
            "end repeat",
            "end repeat",
            "error \(appleScriptStringLiteral("Terminal tab not found for tty \(tty)"))",
            "end tell"
        ]
    }

    private func iTermAutomationArguments(from input: JumpInput?) -> [String] {
        let bundleId = input?.bundleId ?? "com.googlecode.iterm2"
        guard let sessionId = input?.itermSessionId else {
            return [
                "tell application id \(appleScriptStringLiteral(bundleId))",
                "activate",
                "end tell"
            ]
        }

        return [
            "tell application id \(appleScriptStringLiteral(bundleId))",
            "activate",
            "repeat with candidateWindow in windows",
            "repeat with candidateTab in tabs of candidateWindow",
            "repeat with candidateSession in sessions of candidateTab",
            "if id of candidateSession is \(appleScriptStringLiteral(sessionId)) then",
            "select candidateWindow",
            "select candidateTab",
            "select candidateSession",
            "return",
            "end if",
            "end repeat",
            "end repeat",
            "end repeat",
            "error \(appleScriptStringLiteral("iTerm session not found for id \(sessionId)"))",
            "end tell"
        ]
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func descriptor(for handlerId: String?) -> TerminalCapabilityDescriptor? {
        guard let handlerId else {
            return nil
        }
        return registry.descriptor(for: handlerId)
    }
}
