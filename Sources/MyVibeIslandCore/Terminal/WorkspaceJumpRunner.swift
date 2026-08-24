import AppKit
import Foundation

public protocol WorkspaceOpening: Sendable {
    func openWorkspace(path: String) -> WorkspaceOpenResult
}

public enum WorkspaceOpenStatus: String, Codable, Equatable, Sendable {
    case succeeded
    case failed
}

public enum WorkspaceOpenFailureReason: String, Codable, Equatable, Sendable {
    case missingTarget
    case workspaceMissing
    case dependencyMissing
    case openFailed
}

public struct WorkspaceOpenResult: Codable, Equatable, Sendable {
    public let status: WorkspaceOpenStatus
    public let failureReason: WorkspaceOpenFailureReason?
    public let diagnosticSummary: String

    public init(
        status: WorkspaceOpenStatus,
        failureReason: WorkspaceOpenFailureReason? = nil,
        diagnosticSummary: String
    ) {
        self.status = status
        self.failureReason = failureReason
        self.diagnosticSummary = diagnosticSummary
    }

    public static func succeeded(_ diagnosticSummary: String) -> WorkspaceOpenResult {
        WorkspaceOpenResult(status: .succeeded, diagnosticSummary: diagnosticSummary)
    }

    public static func failed(
        _ failureReason: WorkspaceOpenFailureReason,
        diagnosticSummary: String
    ) -> WorkspaceOpenResult {
        WorkspaceOpenResult(status: .failed, failureReason: failureReason, diagnosticSummary: diagnosticSummary)
    }
}

public struct WorkspaceJumpRunner: TerminalJumpActionRunning {
    private let workspaceOpener: WorkspaceOpening
    private let ideWorkspaceOpener: WorkspaceOpening
    private let registry: TerminalRegistry

    public init(opener: WorkspaceOpening, registry: TerminalRegistry = .default) {
        self.init(workspaceOpener: opener, ideWorkspaceOpener: opener, registry: registry)
    }

    public init(
        workspaceOpener: WorkspaceOpening,
        ideWorkspaceOpener: WorkspaceOpening,
        registry: TerminalRegistry = .default
    ) {
        self.workspaceOpener = workspaceOpener
        self.ideWorkspaceOpener = ideWorkspaceOpener
        self.registry = registry
    }

    public func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
        guard action.kind == .openWorkspace else {
            return .failed(
                .unsupportedAction,
                diagnosticSummary: "workspace runner unsupported action: \(action.kind.rawValue)"
            )
        }

        guard let target = action.target, !target.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "workspace runner missing target")
        }

        let result = opener(for: action).openWorkspace(path: target)
        switch result.status {
        case .succeeded:
            return .succeeded(result.diagnosticSummary)
        case .failed:
            return .failed(
                runnerFailureReason(for: result.failureReason),
                diagnosticSummary: result.diagnosticSummary
            )
        }
    }

    private func opener(for action: TerminalJumpActionDescription) -> WorkspaceOpening {
        isIDEWorkspaceAction(action) ? ideWorkspaceOpener : workspaceOpener
    }

    private func isIDEWorkspaceAction(_ action: TerminalJumpActionDescription) -> Bool {
        guard let handlerId = action.handlerId else {
            return false
        }

        if handlerId == "ide-workspace" {
            return true
        }

        guard let descriptor = registry.descriptor(for: handlerId) else {
            return false
        }

        return descriptor.category == .ide
            && descriptor.supportedPrecisions.contains(.workspace)
    }

    private func runnerFailureReason(
        for failureReason: WorkspaceOpenFailureReason?
    ) -> TerminalJumpRunnerFailureReason {
        switch failureReason {
        case .missingTarget, .workspaceMissing, .none:
            return .missingTarget
        case .dependencyMissing:
            return .dependencyMissing
        case .openFailed:
            return .executionFailed
        }
    }
}

public struct SystemWorkspaceOpener: WorkspaceOpening {
    private let fileExists: @Sendable (String) -> Bool
    private let open: @Sendable (String) -> Bool

    public init() {
        self.init { path in
            NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    public init(
        _ open: @escaping @Sendable (String) -> Bool,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.fileExists = fileExists
        self.open = open
    }

    public func openWorkspace(path: String) -> WorkspaceOpenResult {
        guard !path.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "missing workspace target")
        }

        guard fileExists(path) else {
            return .failed(.workspaceMissing, diagnosticSummary: "workspace missing: \(path)")
        }

        guard open(path) else {
            return .failed(.openFailed, diagnosticSummary: "failed to open workspace: \(path)")
        }

        return .succeeded("opened workspace: \(path)")
    }
}

public struct IDEWorkspaceOpener: WorkspaceOpening {
    public static let defaultCandidateCommands = [
        "code",
        "code-insiders",
        "cursor",
        "windsurf",
        "trae",
        "qoder",
        "idea",
        "webstorm",
        "pycharm",
        "goland",
        "rider",
        "clion",
        "phpstorm",
        "rubymine",
        "datagrip"
    ]

    private let candidateCommands: [String]
    private let commandResolver: @Sendable ([String]) -> String?
    private let launch: @Sendable (String, [String]) -> Bool
    private let fileExists: @Sendable (String) -> Bool

    public init(
        candidateCommands: [String] = IDEWorkspaceOpener.defaultCandidateCommands,
        commandResolver: @escaping @Sendable ([String]) -> String? = SystemIDECommandResolver().firstAvailableCommand,
        launch: @escaping @Sendable (String, [String]) -> Bool = SystemIDECommandLauncher().launch,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.candidateCommands = candidateCommands
        self.commandResolver = commandResolver
        self.launch = launch
        self.fileExists = fileExists
    }

    public func openWorkspace(path: String) -> WorkspaceOpenResult {
        guard !path.isEmpty else {
            return .failed(.missingTarget, diagnosticSummary: "missing IDE workspace target")
        }

        guard fileExists(path) else {
            return .failed(.workspaceMissing, diagnosticSummary: "IDE workspace missing: \(path)")
        }

        guard let command = commandResolver(candidateCommands) else {
            return .failed(
                .dependencyMissing,
                diagnosticSummary: "missing IDE CLI command: \(candidateCommands.joined(separator: ", "))"
            )
        }

        let arguments = ["-r", path]
        guard launch(command, arguments) else {
            return .failed(.openFailed, diagnosticSummary: "failed to open IDE workspace with \(command): \(path)")
        }

        return .succeeded("opened IDE workspace with \(command): \(path)")
    }
}

public struct SystemIDECommandResolver: Sendable {
    private let environment: [String: String]
    private let isExecutableFile: @Sendable (String) -> Bool

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.environment = environment
        self.isExecutableFile = isExecutableFile
    }

    public func firstAvailableCommand(from candidates: [String]) -> String? {
        candidates.first { command in
            executablePath(for: command) != nil
        }
    }

    private func executablePath(for command: String) -> String? {
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

public struct SystemIDECommandLauncher: Sendable {
    public init() {}

    public func launch(command: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
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
