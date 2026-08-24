import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitDiagnosticsCoordinatorController {
    public private(set) var lastExportPlan: DiagnosticExportWritePlan?
    public private(set) var lastReadinessSummary: DiagnosticReadinessSummary?

    private let coordinator: DiagnosticsCoordinator
    private let collectInputs: @MainActor () -> [DiagnosticExportSectionInput]
    private let collectSnapshot: @MainActor () -> DiagnosticsCoordinatorSnapshot
    private let collectRepairHints: @MainActor () -> [DiagnosticRepairHint]
    private let publishExportPlan: @MainActor (DiagnosticExportWritePlan) -> Void
    private let publishReadinessSummary: @MainActor (DiagnosticReadinessSummary) -> Void

    public init(
        coordinator: DiagnosticsCoordinator = DiagnosticsCoordinator(),
        collectInputs: @escaping @MainActor () -> [DiagnosticExportSectionInput] = { [] },
        collectSnapshot: @escaping @MainActor () -> DiagnosticsCoordinatorSnapshot = {
            DiagnosticsCoordinatorSnapshot()
        },
        collectRepairHints: @escaping @MainActor () -> [DiagnosticRepairHint] = { [] },
        publishExportPlan: @escaping @MainActor (DiagnosticExportWritePlan) -> Void = { _ in },
        publishReadinessSummary: @escaping @MainActor (DiagnosticReadinessSummary) -> Void = { _ in }
    ) {
        self.coordinator = coordinator
        self.collectInputs = collectInputs
        self.collectSnapshot = collectSnapshot
        self.collectRepairHints = collectRepairHints
        self.publishExportPlan = publishExportPlan
        self.publishReadinessSummary = publishReadinessSummary
    }

    @discardableResult
    public func exportDiagnostics() -> DiagnosticExportWritePlan {
        let plan = coordinator.exportPlan(from: collectInputs())
        lastExportPlan = plan
        publishExportPlan(plan)
        return plan
    }

    @discardableResult
    public func refreshReadinessSummary() -> DiagnosticReadinessSummary {
        let summary = coordinator.readinessSummary(
            for: collectSnapshot(),
            repairHints: collectRepairHints()
        )
        lastReadinessSummary = summary
        publishReadinessSummary(summary)
        return summary
    }
}
