import XCTest
@testable import MyVibeIslandCore

final class IntegrationCoordinatorModelsTests: XCTestCase {
    func testIntegrationCoordinatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            IntegrationCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("agents/integration-coordinator-matrix")
        )

        let coordinator = IntegrationCoordinator(
            registry: AgentRegistry(descriptors: [
                AgentDescriptor(
                    id: "opencode",
                    displayName: "OpenCode",
                    supportLevel: .supported,
                    defaultEventSources: ["jsPlugin"]
                ),
                AgentDescriptor(
                    id: "kimi",
                    displayName: "Kimi CLI",
                    supportLevel: .planned,
                    defaultEventSources: ["hooks"]
                ),
                AgentDescriptor(
                    id: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    defaultEventSources: ["hooks"]
                ),
            ])
        )
        let initialState = coordinator.initialState(lastCheckedAt: "2026-07-09T02:00:00Z")
        let refreshPlan = coordinator.plan(.refresh(at: "2026-07-09T02:05:00Z"), from: initialState)
        let installPlan = coordinator.plan(.install(sourceId: "codex"), from: initialState)
        let repairPlan = coordinator.plan(.repair(sourceId: "opencode"), from: initialState)
        let uninstallPlan = coordinator.plan(.uninstall(sourceId: "codex"), from: initialState)
        let unknownPlan = coordinator.plan(.repair(sourceId: "unknown"), from: initialState)

        let actual = IntegrationCoordinatorMatrixFixture(
            initialRows: initialState.rows.map(IntegrationStatusRowFixture.init(row:)),
            initialLastCheckedAt: initialState.lastCheckedAt,
            plans: [
                planRow(id: "refresh", plan: refreshPlan),
                planRow(id: "install-codex", plan: installPlan),
                planRow(id: "repair-opencode", plan: repairPlan),
                planRow(id: "uninstall-codex", plan: uninstallPlan),
                planRow(id: "unknown-repair", plan: unknownPlan),
            ]
        )
        XCTAssertEqual(actual, expected)
    }

    func testIntegrationCoordinatorStateRoundTripsStatusRows() throws {
        let state = IntegrationCoordinatorState(
            rows: [
                IntegrationStatusRow(
                    sourceId: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    installState: .needsRepair,
                    healthState: .warning,
                    repairAction: "repair",
                    diagnostics: ["Hook path is missing"]
                )
            ],
            lastCheckedAt: "2026-07-08T19:30:00Z"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(IntegrationCoordinatorState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.rows.map(\.sourceId), ["codex"])
    }

    func testIntegrationCoordinatorBuildsDefaultRowsFromRegistry() {
        let coordinator = IntegrationCoordinator(
            registry: AgentRegistry(descriptors: [
                AgentDescriptor(
                    id: "opencode",
                    displayName: "OpenCode",
                    supportLevel: .supported,
                    defaultEventSources: ["jsPlugin"]
                ),
                AgentDescriptor(
                    id: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    defaultEventSources: ["hooks"]
                )
            ])
        )

        let state = coordinator.initialState(lastCheckedAt: "2026-07-08T19:31:00Z")

        XCTAssertEqual(state.rows.map(\.sourceId), ["codex", "opencode"])
        XCTAssertEqual(state.rows.map(\.installState), [.notInstalled, .notInstalled])
        XCTAssertEqual(state.rows.map(\.healthState), [.unknown, .unknown])
        XCTAssertEqual(state.lastCheckedAt, "2026-07-08T19:31:00Z")
    }

    func testIntegrationCoordinatorPlansKnownSourceCommands() {
        let coordinator = IntegrationCoordinator(
            registry: AgentRegistry(descriptors: [
                AgentDescriptor(
                    id: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    defaultEventSources: ["hooks"]
                )
            ])
        )
        let state = IntegrationCoordinatorState(
            rows: [
                IntegrationStatusRow(
                    sourceId: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    installState: .needsRepair,
                    healthState: .failed,
                    repairAction: "repair",
                    diagnostics: ["Hook is stale"]
                )
            ],
            lastCheckedAt: "2026-07-08T19:32:00Z"
        )

        let refresh = coordinator.plan(.refresh(at: "2026-07-08T19:33:00Z"), from: state)
        XCTAssertEqual(refresh.action, .refresh)
        XCTAssertEqual(refresh.nextState.lastCheckedAt, "2026-07-08T19:33:00Z")

        let install = coordinator.plan(.install(sourceId: "codex"), from: state)
        XCTAssertEqual(install.action, .install)
        XCTAssertEqual(install.sourceId, "codex")

        let repair = coordinator.plan(.repair(sourceId: "codex"), from: state)
        XCTAssertEqual(repair.action, .repair)
        XCTAssertEqual(repair.sourceId, "codex")

        let uninstall = coordinator.plan(.uninstall(sourceId: "codex"), from: state)
        XCTAssertEqual(uninstall.action, .uninstall)
        XCTAssertEqual(uninstall.sourceId, "codex")
    }

    func testIntegrationCoordinatorIgnoresUnknownSourceWithoutChangingState() {
        let coordinator = IntegrationCoordinator(
            registry: AgentRegistry(descriptors: [
                AgentDescriptor(
                    id: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    defaultEventSources: ["hooks"]
                )
            ])
        )
        let state = coordinator.initialState(lastCheckedAt: "2026-07-08T19:34:00Z")

        let plan = coordinator.plan(.repair(sourceId: "unknown"), from: state)

        XCTAssertEqual(plan.action, .ignoreUnknownSource)
        XCTAssertNil(plan.sourceId)
        XCTAssertEqual(plan.nextState, state)
    }

    private func planRow(id: String, plan: IntegrationCoordinatorPlan) -> IntegrationCoordinatorPlanFixture {
        IntegrationCoordinatorPlanFixture(
            id: id,
            action: plan.action.rawValue,
            sourceId: plan.sourceId,
            nextLastCheckedAt: plan.nextState.lastCheckedAt,
            nextSourceIds: plan.nextState.rows.map(\.sourceId)
        )
    }

    private struct IntegrationCoordinatorMatrixFixture: Codable, Equatable {
        let initialRows: [IntegrationStatusRowFixture]
        let initialLastCheckedAt: String?
        let plans: [IntegrationCoordinatorPlanFixture]
    }

    private struct IntegrationStatusRowFixture: Codable, Equatable {
        let sourceId: String
        let displayName: String
        let supportLevel: String
        let installState: String
        let healthState: String
        let repairAction: String?
        let diagnostics: [String]

        init(row: IntegrationStatusRow) {
            sourceId = row.sourceId
            displayName = row.displayName
            supportLevel = row.supportLevel.rawValue
            installState = row.installState.rawValue
            healthState = row.healthState.rawValue
            repairAction = row.repairAction
            diagnostics = row.diagnostics
        }
    }

    private struct IntegrationCoordinatorPlanFixture: Codable, Equatable {
        let id: String
        let action: String
        let sourceId: String?
        let nextLastCheckedAt: String?
        let nextSourceIds: [String]
    }
}
