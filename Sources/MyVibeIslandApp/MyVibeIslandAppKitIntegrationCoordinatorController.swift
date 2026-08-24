import Foundation
import MyVibeIslandCore
import MyVibeIslandSetup

@MainActor
public final class MyVibeIslandAppKitIntegrationCoordinatorController {
    public private(set) var state: IntegrationCoordinatorState
    public private(set) var lastPlan: IntegrationCoordinatorPlan?
    public private(set) var lastRepairResult: IntegrationRepairResult?

    private let coordinator: IntegrationCoordinator
    private let refreshIntegrations: @MainActor (String, IntegrationCoordinatorState) -> IntegrationCoordinatorState
    private let installIntegration: @MainActor (String) -> IntegrationRepairResult?
    private let repairIntegration: @MainActor (String) -> IntegrationRepairResult?
    private let uninstallIntegration: @MainActor (String) -> IntegrationRepairResult?

    public init(
        coordinator: IntegrationCoordinator = IntegrationCoordinator(),
        state: IntegrationCoordinatorState? = nil,
        refreshIntegrations: @escaping @MainActor (String, IntegrationCoordinatorState) -> IntegrationCoordinatorState = { timestamp, state in
            IntegrationCoordinatorState(rows: state.rows, lastCheckedAt: timestamp)
        },
        installIntegration: @escaping @MainActor (String) -> IntegrationRepairResult? = { _ in nil },
        repairIntegration: @escaping @MainActor (String) -> IntegrationRepairResult? = { _ in nil },
        uninstallIntegration: @escaping @MainActor (String) -> IntegrationRepairResult? = { _ in nil }
    ) {
        self.coordinator = coordinator
        self.state = state ?? coordinator.initialState()
        self.refreshIntegrations = refreshIntegrations
        self.installIntegration = installIntegration
        self.repairIntegration = repairIntegration
        self.uninstallIntegration = uninstallIntegration
    }

    public static func production(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        scanner: SetupIntegrationScanner = SetupIntegrationScanner(),
        installer: SetupInstaller = SetupInstaller()
    ) -> MyVibeIslandAppKitIntegrationCoordinatorController {
        let coordinator = IntegrationCoordinator()
        return MyVibeIslandAppKitIntegrationCoordinatorController(
            coordinator: coordinator,
            refreshIntegrations: { timestamp, state in
                IntegrationCoordinatorState(
                    rows: scanner.scan(homeDirectory: homeDirectory).map { status in
                        integrationRow(
                            status,
                            supportLevel: state.rows.first(where: {
                                $0.sourceId == status.sourceId
                            })?.supportLevel ?? .supported
                        )
                    },
                    lastCheckedAt: timestamp
                )
            },
            installIntegration: { sourceId in
                productionOperation(
                    .install,
                    sourceId: sourceId,
                    homeDirectory: homeDirectory,
                    scanner: scanner,
                    installer: installer
                )
            },
            repairIntegration: { sourceId in
                productionOperation(
                    .repair,
                    sourceId: sourceId,
                    homeDirectory: homeDirectory,
                    scanner: scanner,
                    installer: installer
                )
            },
            uninstallIntegration: { sourceId in
                productionOperation(
                    .uninstall,
                    sourceId: sourceId,
                    homeDirectory: homeDirectory,
                    scanner: scanner,
                    installer: installer
                )
            }
        )
    }

    @discardableResult
    public func refresh(at timestamp: String) -> IntegrationCoordinatorPlan {
        var plan = coordinator.plan(.refresh(at: timestamp), from: state)
        let refreshedState = refreshIntegrations(timestamp, plan.nextState)
        plan = IntegrationCoordinatorPlan(action: plan.action, sourceId: plan.sourceId, nextState: refreshedState)
        apply(plan)
        return plan
    }

    @discardableResult
    public func install(sourceId: String) -> IntegrationCoordinatorPlan {
        applySourceCommand(.install(sourceId: sourceId), effect: installIntegration)
    }

    @discardableResult
    public func repair(sourceId: String) -> IntegrationCoordinatorPlan {
        applySourceCommand(.repair(sourceId: sourceId), effect: repairIntegration)
    }

    @discardableResult
    public func uninstall(sourceId: String) -> IntegrationCoordinatorPlan {
        applySourceCommand(.uninstall(sourceId: sourceId), effect: uninstallIntegration)
    }

    private func applySourceCommand(
        _ command: IntegrationCoordinatorCommand,
        effect: @MainActor (String) -> IntegrationRepairResult?
    ) -> IntegrationCoordinatorPlan {
        let plan = coordinator.plan(command, from: state)
        lastRepairResult = nil
        if let sourceId = plan.sourceId, plan.action != .ignoreUnknownSource {
            lastRepairResult = effect(sourceId)
        }
        apply(plan)
        return plan
    }

    private func apply(_ plan: IntegrationCoordinatorPlan) {
        state = plan.nextState
        lastPlan = plan
    }

    private static func integrationRow(
        _ status: SetupIntegrationStatus,
        supportLevel: AgentSupportLevel
    ) -> IntegrationStatusRow {
        guard bridgeSupportedSourceIds.contains(status.sourceId) else {
            return IntegrationStatusRow(
                sourceId: status.sourceId,
                displayName: status.displayName,
                supportLevel: supportLevel,
                installState: .unsupported,
                healthState: .unknown,
                diagnostics: status.issues.map(\.rawValue) + ["unsupportedBundledBridgeSource"]
            )
        }

        let installState: IntegrationInstallState
        if status.issues.contains(.managed) {
            installState = .installed
        } else if status.issues.contains(.configMissing) || status.issues.contains(.pluginMissing) {
            installState = .notInstalled
        } else if status.issues.isEmpty {
            installState = .notInstalled
        } else {
            installState = .needsRepair
        }

        let healthState: IntegrationHealthState
        if status.issues.contains(.managed) {
            healthState = .healthy
        } else if status.issues.contains(.configMissing) || status.issues.contains(.pluginMissing) {
            healthState = .unknown
        } else if status.issues.contains(.configMalformed)
            || status.issues.contains(.configUnreadable)
            || status.issues.contains(.configConflict) {
            healthState = .failed
        } else if status.issues.isEmpty {
            healthState = .healthy
        } else {
            healthState = .warning
        }

        return IntegrationStatusRow(
            sourceId: status.sourceId,
            displayName: status.displayName,
            supportLevel: supportLevel,
            installState: installState,
            healthState: healthState,
            repairAction: installState == .needsRepair ? "repair" : nil,
            diagnostics: status.issues.map(\.rawValue)
        )
    }

    private static func productionOperation(
        _ operation: IntegrationRepairOperation,
        sourceId: String,
        homeDirectory: URL,
        scanner: SetupIntegrationScanner,
        installer: SetupInstaller
    ) -> IntegrationRepairResult {
        let before = scanner.scan(homeDirectory: homeDirectory).first { $0.sourceId == sourceId }
        let beforeStatus = hookStatus(before)

        guard bridgeSupportedSourceIds.contains(sourceId) else {
            return IntegrationRepairResult(
                integrationId: sourceId,
                operation: operation,
                outcome: .skipped,
                message: "The bundled bridge does not support \(sourceId)",
                hookStatusBefore: beforeStatus,
                hookStatusAfter: .unsupported,
                diagnosticNotes: ["unsupportedBundledBridgeSource"]
            )
        }

        do {
            let result: SetupInstallResult
            switch operation {
            case .install:
                result = try installer.install(sourceId: sourceId, homeDirectory: homeDirectory)
            case .repair:
                result = try installer.repair(sourceId: sourceId, homeDirectory: homeDirectory)
            case .uninstall:
                result = try installer.uninstall(sourceId: sourceId, homeDirectory: homeDirectory)
            case .addCustomPath, .removeCustomPath:
                preconditionFailure("Custom path operations are not setup operations")
            }
            let after = scanner.scan(homeDirectory: homeDirectory).first { $0.sourceId == sourceId }
            let afterStatus = hookStatus(after)
            let expectedAfter: IntegrationSettingsHookStatus = operation == .uninstall ? .notInstalled : .installed
            let verified = afterStatus == expectedAfter
            return IntegrationRepairResult(
                integrationId: sourceId,
                operation: operation,
                outcome: verified ? .succeeded : .failed,
                message: verified ? result.message : "Post-operation verification failed for \(sourceId)",
                configPath: result.relativePath,
                changedPaths: result.changed ? [result.relativePath] : [],
                hookStatusBefore: beforeStatus,
                hookStatusAfter: afterStatus,
                diagnosticNotes: (after?.issues.map(\.rawValue) ?? [])
                    + (verified ? [] : ["postOperationVerificationFailed"])
            )
        } catch {
            return IntegrationRepairResult(
                integrationId: sourceId,
                operation: operation,
                outcome: .failed,
                message: error.localizedDescription,
                hookStatusBefore: beforeStatus,
                hookStatusAfter: beforeStatus,
                diagnosticNotes: [String(describing: error)]
            )
        }
    }

    private static func hookStatus(_ status: SetupIntegrationStatus?) -> IntegrationSettingsHookStatus {
        guard let status else { return .unsupported }
        if status.issues.contains(.managed) { return .installed }
        if status.issues.contains(.configMissing) || status.issues.contains(.pluginMissing) {
            return .notInstalled
        }
        return status.issues.isEmpty ? .notInstalled : .needsRepair
    }

    private static let bridgeSupportedSourceIds: Set<String> = [
        "claude", "codebuddy", "codex", "cursor", "gemini", "kimi", "qoder", "qwen",
    ]
}
