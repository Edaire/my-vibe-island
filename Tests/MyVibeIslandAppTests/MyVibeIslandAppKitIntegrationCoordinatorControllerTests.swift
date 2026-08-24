import MyVibeIslandCore
import MyVibeIslandSetup
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitIntegrationCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testIntegrationCoordinatorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            IntegrationCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/integration-coordinator-controller-matrix")
        )

        let actual = IntegrationCoordinatorControllerMatrixFixture(rows: [
            row(id: "known-source-full-flow", actions: [.refresh("2026-07-08T20:00:00Z"), .install("codex"), .repair("codex"), .uninstall("codex")]),
            row(id: "unknown-source-ignored", actions: [.repair("unknown")])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRefreshesStateAndRoutesKnownSourceOperationsThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            coordinator: Self.coordinator,
            state: Self.initialState,
            refreshIntegrations: { timestamp, state in
                events.append("refresh:\(timestamp):\(state.rows.count)")
                return IntegrationCoordinatorState(rows: state.rows, lastCheckedAt: timestamp)
            },
            installIntegration: { sourceId in
                events.append("install:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .install)
            },
            repairIntegration: { sourceId in
                events.append("repair:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .repair)
            },
            uninstallIntegration: { sourceId in
                events.append("uninstall:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .uninstall)
            }
        )

        let refreshed = controller.refresh(at: "2026-07-08T20:00:00Z")
        let install = controller.install(sourceId: "codex")
        let repair = controller.repair(sourceId: "codex")
        let uninstall = controller.uninstall(sourceId: "codex")

        XCTAssertEqual(refreshed.action, .refresh)
        XCTAssertEqual(controller.state.lastCheckedAt, "2026-07-08T20:00:00Z")
        XCTAssertEqual(install.action, .install)
        XCTAssertEqual(repair.action, .repair)
        XCTAssertEqual(uninstall.action, .uninstall)
        XCTAssertEqual(controller.lastRepairResult?.operation, .uninstall)
        XCTAssertEqual(events, [
            "refresh:2026-07-08T20:00:00Z:1",
            "install:codex",
            "repair:codex",
            "uninstall:codex"
        ])
    }

    @MainActor
    func testControllerIgnoresUnknownSourcesWithoutRunningSideEffects() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            coordinator: Self.coordinator,
            state: Self.initialState,
            installIntegration: { sourceId in
                events.append("install:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .install)
            },
            repairIntegration: { sourceId in
                events.append("repair:\(sourceId)")
                return nil
            },
            uninstallIntegration: { sourceId in
                events.append("uninstall:\(sourceId)")
                return nil
            }
        )

        _ = controller.install(sourceId: "codex")
        XCTAssertNotNil(controller.lastRepairResult)
        events.removeAll()

        let plan = controller.repair(sourceId: "unknown")

        XCTAssertEqual(plan.action, .ignoreUnknownSource)
        XCTAssertNil(controller.lastRepairResult)
        XCTAssertEqual(controller.state, Self.initialState)
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testProductionRefreshReportsMalformedCodexConfigWithoutMutatingUserFiles() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandIntegrationStatus-" + UUID().uuidString)
        let configURL = home.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let original = Data("{".utf8)
        try original.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: home
        )

        _ = controller.refresh(at: "2026-07-18T00:00:00Z")

        let codex = try XCTUnwrap(controller.state.rows.first { $0.sourceId == "codex" })
        XCTAssertEqual(codex.installState, .needsRepair)
        XCTAssertEqual(codex.healthState, .failed)
        XCTAssertEqual(codex.repairAction, "repair")
        XCTAssertEqual(codex.diagnostics, ["configMalformed"])
        XCTAssertEqual(try Data(contentsOf: configURL), original)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: home.appendingPathComponent(".vibe-island/setup-manifest.json").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: configURL.appendingPathExtension("bak").path
        ))
    }

    @MainActor
    func testProductionInstallMutatesOnlyAfterExplicitCommand() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandIntegrationInstall-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let configURL = home.appendingPathComponent(".codex/hooks.json")
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: home
        )

        _ = controller.refresh(at: "2026-07-18T00:00:00Z")
        XCTAssertFalse(FileManager.default.fileExists(atPath: configURL.path))

        let plan = controller.install(sourceId: "codex")

        XCTAssertEqual(plan.action, .install)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
        XCTAssertEqual(controller.lastRepairResult?.integrationId, "codex")
        XCTAssertEqual(controller.lastRepairResult?.operation, .install)
        XCTAssertEqual(controller.lastRepairResult?.outcome, .succeeded)
        XCTAssertEqual(controller.lastRepairResult?.hookStatusBefore, .notInstalled)
        XCTAssertEqual(controller.lastRepairResult?.hookStatusAfter, .installed)
        XCTAssertEqual(controller.lastRepairResult?.changedPaths, [".codex/hooks.json"])
    }

    @MainActor
    func testProductionRefreshMarksSourcesUnsupportedByBundledBridge() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandUnsupportedIntegration-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: home
        )

        _ = controller.refresh(at: "2026-07-18T00:00:00Z")

        XCTAssertEqual(
            controller.state.rows.first { $0.sourceId == "factory" }?.installState,
            .unsupported
        )
        XCTAssertEqual(
            controller.state.rows.first { $0.sourceId == "opencode" }?.installState,
            .unsupported
        )
    }

    @MainActor
    func testProductionOperationFailsWhenPostOperationScanCannotVerifyState() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandUnverifiedIntegration-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: home,
            scanner: SetupIntegrationScanner(sources: [])
        )

        _ = controller.install(sourceId: "codex")

        XCTAssertEqual(controller.lastRepairResult?.outcome, .failed)
        XCTAssertEqual(controller.lastRepairResult?.hookStatusAfter, .unsupported)
        XCTAssertTrue(controller.lastRepairResult?.diagnosticNotes.contains("postOperationVerificationFailed") == true)
    }

    @MainActor
    func testProductionRepairAndUninstallCompleteLifecycle() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandIntegrationLifecycle-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: home
        )

        _ = controller.install(sourceId: "codex")
        _ = controller.repair(sourceId: "codex")
        XCTAssertEqual(controller.lastRepairResult?.operation, .repair)
        XCTAssertEqual(controller.lastRepairResult?.outcome, .succeeded)
        XCTAssertEqual(controller.lastRepairResult?.hookStatusAfter, .installed)

        _ = controller.uninstall(sourceId: "codex")
        XCTAssertEqual(controller.lastRepairResult?.operation, .uninstall)
        XCTAssertEqual(controller.lastRepairResult?.outcome, .succeeded)
        XCTAssertEqual(controller.lastRepairResult?.hookStatusAfter, .notInstalled)
    }

    private static let coordinator = IntegrationCoordinator(
        registry: AgentRegistry(descriptors: [
            AgentDescriptor(
                id: "codex",
                displayName: "Codex CLI",
                supportLevel: .supported,
                defaultEventSources: ["hooks"]
            )
        ])
    )

    private static let initialState = IntegrationCoordinatorState(rows: [
        IntegrationStatusRow(
            sourceId: "codex",
            displayName: "Codex CLI",
            supportLevel: .supported,
            installState: .needsRepair,
            healthState: .warning,
            repairAction: "repair",
            diagnostics: ["Hook is stale"]
        )
    ], lastCheckedAt: nil)

    private static func repairResult(
        sourceId: String,
        operation: IntegrationRepairOperation
    ) -> IntegrationRepairResult {
        IntegrationRepairResult(
            integrationId: sourceId,
            operation: operation,
            outcome: .succeeded,
            message: "\(operation.rawValue) completed",
            hookStatusBefore: .needsRepair,
            hookStatusAfter: operation == .uninstall ? .notInstalled : .installed
        )
    }

    @MainActor
    private func row(
        id: String,
        actions: [IntegrationCoordinatorControllerFixtureAction]
    ) -> IntegrationCoordinatorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            coordinator: Self.coordinator,
            state: Self.initialState,
            refreshIntegrations: { timestamp, state in
                events.append("refresh:\(timestamp):\(state.rows.count)")
                return IntegrationCoordinatorState(rows: state.rows, lastCheckedAt: timestamp)
            },
            installIntegration: { sourceId in
                events.append("install:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .install)
            },
            repairIntegration: { sourceId in
                events.append("repair:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .repair)
            },
            uninstallIntegration: { sourceId in
                events.append("uninstall:\(sourceId)")
                return Self.repairResult(sourceId: sourceId, operation: .uninstall)
            }
        )
        var outcomes: [String] = []

        for action in actions {
            let plan: IntegrationCoordinatorPlan
            switch action {
            case let .refresh(timestamp): plan = controller.refresh(at: timestamp)
            case let .install(sourceId): plan = controller.install(sourceId: sourceId)
            case let .repair(sourceId): plan = controller.repair(sourceId: sourceId)
            case let .uninstall(sourceId): plan = controller.uninstall(sourceId: sourceId)
            }
            outcomes.append("\(plan.action.rawValue):\(plan.sourceId ?? "none")")
        }

        return IntegrationCoordinatorControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            outcomes: outcomes,
            state: IntegrationCoordinatorStateSummary(controller.state),
            lastPlanAction: controller.lastPlan?.action.rawValue,
            lastRepairOperation: controller.lastRepairResult?.operation.rawValue,
            lastRepairOutcome: controller.lastRepairResult?.outcome.rawValue,
            events: events
        )
    }
}

private enum IntegrationCoordinatorControllerFixtureAction {
    case refresh(String)
    case install(String)
    case repair(String)
    case uninstall(String)

    var summary: String {
        switch self {
        case let .refresh(timestamp): "refresh:\(timestamp)"
        case let .install(sourceId): "install:\(sourceId)"
        case let .repair(sourceId): "repair:\(sourceId)"
        case let .uninstall(sourceId): "uninstall:\(sourceId)"
        }
    }
}

private struct IntegrationCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [IntegrationCoordinatorControllerMatrixRow]
}

private struct IntegrationCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let outcomes: [String]
    let state: IntegrationCoordinatorStateSummary
    let lastPlanAction: String?
    let lastRepairOperation: String?
    let lastRepairOutcome: String?
    let events: [String]
}

private struct IntegrationCoordinatorStateSummary: Codable, Equatable {
    let sourceIds: [String]
    let installStates: [String]
    let healthStates: [String]
    let lastCheckedAt: String?

    init(_ state: IntegrationCoordinatorState) {
        self.sourceIds = state.rows.map(\.sourceId)
        self.installStates = state.rows.map { $0.installState.rawValue }
        self.healthStates = state.rows.map { $0.healthState.rawValue }
        self.lastCheckedAt = state.lastCheckedAt
    }
}
