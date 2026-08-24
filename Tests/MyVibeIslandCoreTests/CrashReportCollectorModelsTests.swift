import XCTest
@testable import MyVibeIslandCore

final class CrashReportCollectorModelsTests: XCTestCase {
    func testCrashReportCollectorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CrashReportCollectorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/crash-report-collector-matrix")
        )

        let thisApp = CrashReportMetadata(
            reportIDHash: "hash-this-app",
            processName: "MyVibeIsland",
            occurredAt: "2026-07-09T09:00:00Z",
            appVersion: "1.2.0",
            redactedExceptionType: "EXC_BAD_ACCESS"
        )
        let otherApp = CrashReportMetadata(
            reportIDHash: "hash-other-app",
            processName: "OtherApp",
            occurredAt: "2026-07-09T09:01:00Z",
            appVersion: nil,
            redactedExceptionType: nil
        )
        let collector = CrashReportCollector(appProcessName: "MyVibeIsland")
        let actual = CrashReportCollectorMatrixFixture(rows: [
            row(
                id: "explicit-inclusion-disabled",
                plan: collector.inclusionPlan(
                    reports: [thisApp, otherApp],
                    policy: CrashReportInclusionPolicy(explicitlyIncluded: false)
                )
            ),
            row(
                id: "explicit-inclusion-filters-this-app",
                plan: collector.inclusionPlan(
                    reports: [thisApp, otherApp],
                    policy: CrashReportInclusionPolicy(explicitlyIncluded: true)
                )
            ),
            row(
                id: "explicit-inclusion-empty-input",
                plan: collector.inclusionPlan(
                    reports: [],
                    policy: CrashReportInclusionPolicy(explicitlyIncluded: true)
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCrashReportMetadataRoundTripsRedactedFields() throws {
        let metadata = CrashReportMetadata(
            reportIDHash: "hash-1",
            processName: "MyVibeIsland",
            occurredAt: "2026-07-08T12:30:00Z",
            appVersion: "1.0.0",
            redactedExceptionType: "EXC_BAD_ACCESS"
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(CrashReportMetadata.self, from: data)

        XCTAssertEqual(decoded, metadata)
        XCTAssertEqual(decoded.redactedExceptionType, "EXC_BAD_ACCESS")
    }

    func testCollectorPlansOnlyExplicitThisAppCrashReportMetadata() {
        let collector = CrashReportCollector(appProcessName: "MyVibeIsland")
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

        let excluded = collector.inclusionPlan(
            reports: [thisApp, otherApp],
            policy: CrashReportInclusionPolicy(explicitlyIncluded: false)
        )
        XCTAssertFalse(excluded.isIncluded)
        XCTAssertTrue(excluded.reports.isEmpty)

        let included = collector.inclusionPlan(
            reports: [thisApp, otherApp],
            policy: CrashReportInclusionPolicy(explicitlyIncluded: true)
        )
        XCTAssertTrue(included.isIncluded)
        XCTAssertEqual(included.reports, [thisApp])
        XCTAssertEqual(included.excludedReportCount, 1)
    }

    private func row(
        id: String,
        plan: CrashReportInclusionPlan
    ) -> CrashReportCollectorRowFixture {
        CrashReportCollectorRowFixture(
            id: id,
            isIncluded: plan.isIncluded,
            includedReportCount: plan.reports.count,
            excludedReportCount: plan.excludedReportCount,
            firstReportIDHash: plan.reports.first?.reportIDHash,
            firstProcessName: plan.reports.first?.processName,
            firstOccurredAt: plan.reports.first?.occurredAt,
            firstAppVersion: plan.reports.first?.appVersion,
            firstRedactedExceptionType: plan.reports.first?.redactedExceptionType
        )
    }

    private struct CrashReportCollectorMatrixFixture: Codable, Equatable {
        let rows: [CrashReportCollectorRowFixture]
    }

    private struct CrashReportCollectorRowFixture: Codable, Equatable {
        let id: String
        let isIncluded: Bool
        let includedReportCount: Int
        let excludedReportCount: Int
        let firstReportIDHash: String?
        let firstProcessName: String?
        let firstOccurredAt: String?
        let firstAppVersion: String?
        let firstRedactedExceptionType: String?
    }
}
