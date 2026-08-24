import XCTest
@testable import MyVibeIslandSetup

final class SetupPlannerTests: XCTestCase {
    func testMissingJsonSourcePlansCreateConfigAndRegisterHooks() throws {
        let status = status(sourceId: "codex", relativePath: ".codex/hooks.json", issues: [.configMissing])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.createConfigFile, .registerManagedHooks])
        XCTAssertTrue(plan.wouldChange)
        XCTAssertFalse(plan.blocked)
    }

    func testHooksDetectedPlansPreserveExistingHooksAndRegisterManagedHooks() throws {
        let status = status(sourceId: "claude", relativePath: ".claude/settings.json", issues: [.hooksDetected])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.preserveExistingHooks, .registerManagedHooks])
        XCTAssertTrue(plan.wouldChange)
        XCTAssertFalse(plan.blocked)
    }

    func testMalformedConfigPlansBlockedManualRepairWithoutChangingFiles() throws {
        let status = status(sourceId: "cursor", relativePath: ".cursor/hooks.json", malformed: true, issues: [.configMalformed])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.manualRepairRequired])
        XCTAssertFalse(plan.wouldChange)
        XCTAssertTrue(plan.blocked)
        XCTAssertTrue(plan.steps.allSatisfy { !$0.wouldChange })
    }

    func testMissingOpenCodePluginPlansCopyPluginFile() throws {
        let status = status(sourceId: "opencode", relativePath: ".config/opencode/plugins/open-island.js", issues: [.pluginMissing])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.copyPluginFile])
        XCTAssertTrue(plan.wouldChange)
        XCTAssertFalse(plan.blocked)
    }

    func testExistingOpenCodePluginPlansNoChangeNeeded() throws {
        let status = status(sourceId: "opencode", relativePath: ".config/opencode/plugins/open-island.js", issues: [.pluginPresent])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.noChangeNeeded])
        XCTAssertFalse(plan.wouldChange)
        XCTAssertFalse(plan.blocked)
    }

    func testUnmanagedOpenCodePluginPlansBlockedManualRepairWithoutChangingFiles() throws {
        let status = status(sourceId: "opencode", relativePath: ".config/opencode/plugins/open-island.js", issues: [.pluginUnmanaged])

        let plan = SetupPlanner().plan(for: status, action: .dryRun)

        XCTAssertEqual(plan.steps.map(\.kind), [.manualRepairRequired])
        XCTAssertFalse(plan.wouldChange)
        XCTAssertTrue(plan.blocked)
        XCTAssertTrue(plan.steps.first?.message.contains("unmanaged plugin") == true)
    }

    private func status(
        sourceId: String,
        displayName: String = "Test Source",
        relativePath: String,
        malformed: Bool = false,
        issues: [SetupIntegrationIssue]
    ) -> SetupIntegrationStatus {
        SetupIntegrationStatus(
            sourceId: sourceId,
            displayName: displayName,
            relativePath: relativePath,
            absolutePath: "/tmp/\(relativePath)",
            exists: !issues.contains(.configMissing) && !issues.contains(.pluginMissing),
            readable: !issues.contains(.configUnreadable),
            malformed: malformed,
            issues: issues
        )
    }
}
