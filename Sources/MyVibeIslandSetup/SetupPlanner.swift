public enum SetupAction: String, Sendable {
    case status
    case install
    case uninstall
    case repair
    case dryRun
    case explain
}

public enum SetupPlanStepKind: String, Sendable {
    case createConfigFile
    case registerManagedHooks
    case preserveExistingHooks
    case copyPluginFile
    case manualRepairRequired
    case noChangeNeeded
}

public struct SetupPlanStep: Sendable {
    public let kind: SetupPlanStepKind
    public let sourceId: String
    public let relativePath: String
    public let message: String
    public let wouldChange: Bool
    public let blocked: Bool
}

public struct SetupPlan: Sendable {
    public let sourceId: String
    public let displayName: String
    public let action: SetupAction
    public let relativePath: String
    public let issues: [SetupIntegrationIssue]
    public let steps: [SetupPlanStep]

    public var wouldChange: Bool {
        steps.contains { $0.wouldChange && !$0.blocked }
    }

    public var blocked: Bool {
        steps.contains { $0.blocked }
    }
}

public struct SetupPlanner: Sendable {
    public init() {}

    public func plan(for status: SetupIntegrationStatus, action: SetupAction) -> SetupPlan {
        SetupPlan(
            sourceId: status.sourceId,
            displayName: status.displayName,
            action: action,
            relativePath: status.relativePath,
            issues: status.issues,
            steps: steps(for: status)
        )
    }

    private func steps(for status: SetupIntegrationStatus) -> [SetupPlanStep] {
        if status.issues.contains(.managed) {
            return [step(.noChangeNeeded, status: status, message: "no change needed", wouldChange: false)]
        }
        if status.issues.contains(.managedStale) {
            return [step(.registerManagedHooks, status: status, message: "would repair stale managed hooks", wouldChange: true)]
        }
        if status.issues.contains(.configConflict) {
            return [step(.manualRepairRequired, status: status, message: "manual repair required for conflicting config", wouldChange: false, blocked: true)]
        }
        if status.issues.contains(.configMalformed) {
            return [step(.manualRepairRequired, status: status, message: "manual repair required for malformed config", wouldChange: false, blocked: true)]
        }
        if status.issues.contains(.configUnreadable) {
            return [step(.manualRepairRequired, status: status, message: "manual repair required for unreadable config", wouldChange: false, blocked: true)]
        }
        if status.issues.contains(.pluginUnmanaged) {
            return [step(.manualRepairRequired, status: status, message: "manual repair required for unmanaged plugin", wouldChange: false, blocked: true)]
        }
        if status.issues.contains(.pluginMissing) {
            return [step(.copyPluginFile, status: status, message: "would copy managed plugin file", wouldChange: true)]
        }
        if status.issues.contains(.pluginPresent) {
            return [step(.noChangeNeeded, status: status, message: "no change needed", wouldChange: false)]
        }
        if status.issues.contains(.configMissing) {
            return [
                step(.createConfigFile, status: status, message: "would create config file", wouldChange: true),
                step(.registerManagedHooks, status: status, message: "would register managed hooks", wouldChange: true),
            ]
        }
        if status.issues.contains(.hooksDetected) {
            return [
                step(.preserveExistingHooks, status: status, message: "would preserve existing hooks", wouldChange: false),
                step(.registerManagedHooks, status: status, message: "would register managed hooks", wouldChange: true),
            ]
        }
        return [step(.registerManagedHooks, status: status, message: "would register managed hooks", wouldChange: true)]
    }

    private func step(
        _ kind: SetupPlanStepKind,
        status: SetupIntegrationStatus,
        message: String,
        wouldChange: Bool,
        blocked: Bool = false
    ) -> SetupPlanStep {
        SetupPlanStep(
            kind: kind,
            sourceId: status.sourceId,
            relativePath: status.relativePath,
            message: message,
            wouldChange: wouldChange,
            blocked: blocked
        )
    }
}
