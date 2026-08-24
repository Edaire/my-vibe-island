import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitUpdateCheckerController {
    public private(set) var currentVersion: String
    public private(set) var settings: UpdateCheckerSettings
    public private(set) var lastPlan: UpdateCheckerPlan?

    private let isConfigured: Bool
    private let checker: UpdateChecker
    private let presentManualCheck: @MainActor () -> Void
    private let presentUnavailable: @MainActor () -> Void
    private let performCheck: @MainActor (UpdateCheckRequest) -> Void

    public init(
        currentVersion: String,
        isConfigured: Bool = true,
        settings: UpdateCheckerSettings = UpdateCheckerSettings(),
        checker: UpdateChecker = UpdateChecker(),
        presentManualCheck: @escaping @MainActor () -> Void = {},
        presentUnavailable: @escaping @MainActor () -> Void = {},
        performCheck: @escaping @MainActor (UpdateCheckRequest) -> Void = { _ in }
    ) {
        self.currentVersion = currentVersion
        self.isConfigured = isConfigured
        self.settings = settings
        self.checker = checker
        self.presentManualCheck = presentManualCheck
        self.presentUnavailable = presentUnavailable
        self.performCheck = performCheck
    }

    public func updateSettings(_ settings: UpdateCheckerSettings) {
        self.settings = settings
    }

    @discardableResult
    public func checkForUpdates() -> UpdateCheckerPlan {
        guard isConfigured else {
            let plan = UpdateCheckerPlan(action: .updatesUnavailable)
            lastPlan = plan
            presentUnavailable()
            return plan
        }
        let plan = checker.plan(.manualCheck(currentVersion: currentVersion), settings: settings)
        lastPlan = plan
        presentManualCheck()
        apply(plan)
        return plan
    }

    @discardableResult
    public func checkForUpdatesInBackground() -> UpdateCheckerPlan {
        guard isConfigured else {
            let plan = UpdateCheckerPlan(action: .updatesUnavailable)
            lastPlan = plan
            return plan
        }
        let plan = checker.plan(.backgroundCheck(currentVersion: currentVersion), settings: settings)
        lastPlan = plan
        apply(plan)
        return plan
    }

    private func apply(_ plan: UpdateCheckerPlan) {
        guard let request = plan.request else {
            return
        }
        performCheck(request)
    }
}
