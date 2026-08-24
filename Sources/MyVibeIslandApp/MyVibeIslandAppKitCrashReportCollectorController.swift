import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitCrashReportCollectorController {
    public private(set) var lastPlan: CrashReportInclusionPlan?

    private let collector: CrashReportCollector
    private let policy: CrashReportInclusionPolicy
    private let collectReports: @MainActor () -> [CrashReportMetadata]
    private let publishPlan: @MainActor (CrashReportInclusionPlan) -> Void

    public init(
        collector: CrashReportCollector = CrashReportCollector(appProcessName: "MyVibeIsland"),
        policy: CrashReportInclusionPolicy = CrashReportInclusionPolicy(explicitlyIncluded: false),
        collectReports: @escaping @MainActor () -> [CrashReportMetadata] = { [] },
        publishPlan: @escaping @MainActor (CrashReportInclusionPlan) -> Void = { _ in }
    ) {
        self.collector = collector
        self.policy = policy
        self.collectReports = collectReports
        self.publishPlan = publishPlan
    }

    @discardableResult
    public func refreshInclusionPlan() -> CrashReportInclusionPlan {
        let plan = collector.inclusionPlan(
            reports: collectReports(),
            policy: policy
        )
        lastPlan = plan
        publishPlan(plan)
        return plan
    }
}
