import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitCrashReportCollectorControllerTests: XCTestCase {
    @MainActor
    func testCrashReportCollectorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CrashReportCollectorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/crash-report-collector-controller-matrix")
        )
        let thisApp = CrashReportMetadata(
            reportIDHash: "hash-this-app",
            processName: "MyVibeIsland",
            occurredAt: "2026-07-08T12:30:00Z"
        )
        let otherApp = CrashReportMetadata(
            reportIDHash: "hash-other-app",
            processName: "OtherApp",
            occurredAt: "2026-07-08T12:31:00Z"
        )

        let actual = CrashReportCollectorControllerMatrixFixture(rows: [
            row(id: "opted-in-filters-other-app", explicitlyIncluded: true, reports: [thisApp, otherApp]),
            row(id: "opted-out-excludes-all", explicitlyIncluded: false, reports: [thisApp])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerBuildsInclusionPlanFromCollectedRedactedMetadata() {
        var events: [String] = []
        let thisApp = CrashReportMetadata(
            reportIDHash: "hash-this-app",
            processName: "MyVibeIsland",
            occurredAt: "2026-07-08T12:30:00Z"
        )
        let otherApp = CrashReportMetadata(
            reportIDHash: "hash-other-app",
            processName: "OtherApp",
            occurredAt: "2026-07-08T12:31:00Z"
        )
        let controller = MyVibeIslandAppKitCrashReportCollectorController(
            collector: CrashReportCollector(appProcessName: "MyVibeIsland"),
            policy: CrashReportInclusionPolicy(explicitlyIncluded: true),
            collectReports: { [thisApp, otherApp] },
            publishPlan: { plan in
                events.append("plan:\(plan.isIncluded):\(plan.reports.count):\(plan.excludedReportCount)")
            }
        )

        let plan = controller.refreshInclusionPlan()

        XCTAssertTrue(plan.isIncluded)
        XCTAssertEqual(plan.reports, [thisApp])
        XCTAssertEqual(plan.excludedReportCount, 1)
        XCTAssertEqual(controller.lastPlan, plan)
        XCTAssertEqual(events, ["plan:true:1:1"])
    }

    @MainActor
    func testControllerExcludesReportsWhenPolicyIsNotOptedIn() {
        let thisApp = CrashReportMetadata(
            reportIDHash: "hash-this-app",
            processName: "MyVibeIsland",
            occurredAt: "2026-07-08T12:30:00Z"
        )
        let controller = MyVibeIslandAppKitCrashReportCollectorController(
            collector: CrashReportCollector(appProcessName: "MyVibeIsland"),
            policy: CrashReportInclusionPolicy(explicitlyIncluded: false),
            collectReports: { [thisApp] }
        )

        let plan = controller.refreshInclusionPlan()

        XCTAssertFalse(plan.isIncluded)
        XCTAssertEqual(plan.reports, [])
        XCTAssertEqual(plan.excludedReportCount, 1)
        XCTAssertEqual(controller.lastPlan, plan)
    }

    @MainActor
    private func row(
        id: String,
        explicitlyIncluded: Bool,
        reports: [CrashReportMetadata]
    ) -> CrashReportCollectorControllerMatrixRow {
        var events: [CrashReportInclusionPlan] = []
        let controller = MyVibeIslandAppKitCrashReportCollectorController(
            collector: CrashReportCollector(appProcessName: "MyVibeIsland"),
            policy: CrashReportInclusionPolicy(explicitlyIncluded: explicitlyIncluded),
            collectReports: { reports },
            publishPlan: { events.append($0) }
        )
        let plan = controller.refreshInclusionPlan()

        return CrashReportCollectorControllerMatrixRow(
            id: id,
            plan: plan,
            lastPlan: controller.lastPlan,
            events: events
        )
    }
}

private struct CrashReportCollectorControllerMatrixFixture: Codable, Equatable {
    let rows: [CrashReportCollectorControllerMatrixRow]
}

private struct CrashReportCollectorControllerMatrixRow: Codable, Equatable {
    let id: String
    let plan: CrashReportInclusionPlan
    let lastPlan: CrashReportInclusionPlan?
    let events: [CrashReportInclusionPlan]
}
