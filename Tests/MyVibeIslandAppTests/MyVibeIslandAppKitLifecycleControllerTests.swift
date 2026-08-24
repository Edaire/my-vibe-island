import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitLifecycleControllerTests: XCTestCase {
    @MainActor
    func testLifecycleControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LifecycleControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/lifecycle-controller-matrix")
        )

        let actual = LifecycleControllerMatrixFixture(rows: [
            row(
                id: "startup-sequence",
                actions: [
                    .apply(.createRuntime),
                    .apply(.loadSettings),
                    .apply(.startBridge),
                    .apply(.showIsland)
                ]
            ),
            row(
                id: "ignored-disabled-maintenance-menu",
                actions: [
                    .ignore(.checkForUpdates),
                    .ignore(.exportDiagnostics)
                ]
            ),
            row(
                id: "termination-sequence",
                actions: [
                    .apply(.persistSettingsAndSessions),
                    .apply(.unregisterShortcuts),
                    .apply(.closeWindows),
                    .apply(.stopBridge),
                    .apply(.flushDiagnostics)
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRecordsLifecycleStepsAndIgnoredMenuCommands() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitLifecycleController(
            applyStep: { step in
                events.append("step:\(step.rawValue)")
            },
            ignoreMenuCommand: { command in
                events.append("ignored:\(command)")
            }
        )

        controller.apply(.createRuntime)
        controller.apply(.startBridge)
        controller.ignore(.exportDiagnostics)

        XCTAssertEqual(controller.appliedSteps, [.createRuntime, .startBridge])
        XCTAssertEqual(controller.ignoredMenuCommands, [.exportDiagnostics])
        XCTAssertEqual(events, [
            "step:createRuntime",
            "step:startBridge",
            "ignored:exportDiagnostics"
        ])
    }

    @MainActor
    func testControllerPublishesLastLifecycleActionForOrchestration() {
        let controller = MyVibeIslandAppKitLifecycleController(
            applyStep: { _ in },
            ignoreMenuCommand: { _ in }
        )

        controller.apply(.createRuntime)

        XCTAssertEqual(controller.lastAction, .applyStep(.createRuntime))

        controller.ignore(.exportDiagnostics)

        XCTAssertEqual(controller.lastAction, .ignoreMenuCommand(.exportDiagnostics))
    }

    @MainActor
    private func row(
        id: String,
        actions: [LifecycleControllerFixtureAction]
    ) -> LifecycleControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitLifecycleController(
            applyStep: { step in
                events.append("step:\(step.rawValue)")
            },
            ignoreMenuCommand: { command in
                events.append("ignored:\(command.summary)")
            }
        )

        for action in actions {
            switch action {
            case let .apply(step):
                controller.apply(step)
            case let .ignore(command):
                controller.ignore(command)
            }
        }

        return LifecycleControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            appliedSteps: controller.appliedSteps.map(\.rawValue),
            ignoredMenuCommands: controller.ignoredMenuCommands.map(\.summary),
            lastAction: controller.lastAction?.summary,
            events: events
        )
    }
}

private struct LifecycleControllerMatrixFixture: Codable, Equatable {
    let rows: [LifecycleControllerMatrixRow]
}

private struct LifecycleControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let appliedSteps: [String]
    let ignoredMenuCommands: [String]
    let lastAction: String?
    let events: [String]
}

private enum LifecycleControllerFixtureAction {
    case apply(AppLifecycleStep)
    case ignore(AppCommand)

    var summary: String {
        switch self {
        case let .apply(step):
            return "apply:\(step.rawValue)"
        case let .ignore(command):
            return "ignore:\(command.summary)"
        }
    }
}

private extension MyVibeIslandAppKitLifecycleAction {
    var summary: String {
        switch self {
        case let .applyStep(step):
            return "apply:\(step.rawValue)"
        case let .ignoreMenuCommand(command):
            return "ignore:\(command.summary)"
        }
    }
}

private extension AppCommand {
    var summary: String {
        switch self {
        case .openSettings:
            return "openSettings"
        case .checkForUpdates:
            return "checkForUpdates"
        case .exportDiagnostics:
            return "exportDiagnostics"
        case .toggleDockIcon:
            return "toggleDockIcon"
        case .toggleLaunchAtLogin:
            return "toggleLaunchAtLogin"
        case let .selectScreenMode(mode):
            return "selectScreenMode:\(mode.rawValue)"
        case .quit:
            return "quit"
        }
    }
}
