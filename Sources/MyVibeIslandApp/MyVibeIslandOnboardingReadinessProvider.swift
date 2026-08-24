import MyVibeIslandCore

public struct MyVibeIslandOnboardingReadinessProvider: Sendable {
    public init() {}

    public func state(
        from integrations: IntegrationCoordinatorState,
        restartHint: RestartBannerState = RestartBannerState()
    ) -> OnboardingReadyWindowState {
        let readiness = ReadinessScanResult(
            generatedAt: integrations.lastCheckedAt,
            agents: integrations.rows.map(agentReadiness)
        )
        return OnboardingReadyModel().state(
            readiness: readiness,
            restartHint: restartHint
        )
    }

    private func agentReadiness(_ row: IntegrationStatusRow) -> AgentReadiness {
        AgentReadiness(
            agentId: row.sourceId,
            supportLevel: row.supportLevel,
            installedState: installedState(row.installState),
            hookConfiguredState: hookState(row.installState),
            watcherAvailableState: watcherState(row.healthState),
            repairAction: row.repairAction,
            blockingIssue: blockingIssue(row),
            lastCheckedAt: nil
        )
    }

    private func installedState(_ state: IntegrationInstallState) -> OnboardingInstalledState {
        switch state {
        case .installed: .installed
        case .notInstalled: .missing
        case .needsRepair, .unsupported: .unknown
        }
    }

    private func hookState(_ state: IntegrationInstallState) -> OnboardingHookConfiguredState {
        switch state {
        case .installed: .configured
        case .notInstalled: .missing
        case .needsRepair, .unsupported: .unknown
        }
    }

    private func watcherState(_ state: IntegrationHealthState) -> OnboardingAvailabilityState {
        switch state {
        case .healthy: .available
        case .failed: .unavailable
        case .unknown, .warning: .unknown
        }
    }

    private func blockingIssue(_ row: IntegrationStatusRow) -> String? {
        guard row.healthState == .failed else { return nil }
        return row.diagnostics.first ?? "\(row.displayName) integration failed"
    }
}
