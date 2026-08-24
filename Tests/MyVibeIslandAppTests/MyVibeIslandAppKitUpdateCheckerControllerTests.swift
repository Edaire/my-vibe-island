import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitUpdateCheckerControllerTests: XCTestCase {
    @MainActor
    func testUpdateCheckerControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UpdateCheckerControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/update-checker-controller-matrix")
        )

        let actual = UpdateCheckerControllerMatrixFixture(rows: [
            row(
                id: "manual-check",
                currentVersion: "1.0.0",
                initialSettings: UpdateCheckerSettings(
                    automaticChecksEnabled: false,
                    automaticInstallEnabled: true
                ),
                actions: [.manual]
            ),
            row(
                id: "disabled-then-enabled-background",
                currentVersion: "1.2.0",
                initialSettings: UpdateCheckerSettings(automaticChecksEnabled: false),
                actions: [
                    .background,
                    .updateSettings(UpdateCheckerSettings(
                        automaticChecksEnabled: true,
                        automaticInstallEnabled: true
                    )),
                    .background
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testManualCheckPresentsCheckingStateAndRunsMinimalRequest() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: "1.0.0",
            settings: UpdateCheckerSettings(
                automaticChecksEnabled: false,
                automaticInstallEnabled: true
            ),
            presentManualCheck: {
                events.append("present")
            },
            performCheck: { request in
                events.append("check:\(request.kind.rawValue):\(request.currentVersion):\(request.automaticInstallAllowed)")
            }
        )

        let plan = controller.checkForUpdates()

        XCTAssertEqual(plan.action, .startManualCheck)
        XCTAssertEqual(events, [
            "present",
            "check:manual:1.0.0:false"
        ])
        XCTAssertEqual(controller.lastPlan?.request?.kind, .manual)
    }

    @MainActor
    func testBackgroundCheckRunsOnlyWhenAutomaticChecksAreEnabled() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: "1.0.0",
            settings: UpdateCheckerSettings(automaticChecksEnabled: false),
            presentManualCheck: {
                events.append("present")
            },
            performCheck: { request in
                events.append("check:\(request.kind.rawValue)")
            }
        )

        let disabled = controller.checkForUpdatesInBackground()
        controller.updateSettings(UpdateCheckerSettings(
            automaticChecksEnabled: true,
            automaticInstallEnabled: true
        ))
        let enabled = controller.checkForUpdatesInBackground()

        XCTAssertEqual(disabled.action, .skipBackgroundCheck)
        XCTAssertEqual(enabled.action, .startBackgroundCheck)
        XCTAssertEqual(enabled.request?.automaticInstallAllowed, true)
        XCTAssertEqual(events, ["check:background"])
    }

    @MainActor
    func testUnconfiguredBuildNeverCreatesRequestOrInvokesTransport() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: "1.0.0",
            isConfigured: false,
            presentUnavailable: { events.append("unavailable") },
            performCheck: { _ in events.append("network") }
        )

        let manual = controller.checkForUpdates()
        let background = controller.checkForUpdatesInBackground()

        XCTAssertEqual(manual.action, .updatesUnavailable)
        XCTAssertNil(manual.request)
        XCTAssertEqual(background.action, .updatesUnavailable)
        XCTAssertNil(background.request)
        XCTAssertEqual(events, ["unavailable"])
    }

    @MainActor
    private func row(
        id: String,
        currentVersion: String,
        initialSettings: UpdateCheckerSettings,
        actions: [UpdateCheckerControllerFixtureAction]
    ) -> UpdateCheckerControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: currentVersion,
            settings: initialSettings,
            presentManualCheck: {
                events.append("present")
            },
            performCheck: { request in
                events.append(
                    "check:\(request.kind.rawValue):\(request.currentVersion):\(request.automaticInstallAllowed)"
                )
            }
        )
        var planActions: [String] = []
        var requests: [UpdateCheckRequestSummary?] = []

        for action in actions {
            switch action {
            case .manual:
                let plan = controller.checkForUpdates()
                planActions.append(plan.action.rawValue)
                requests.append(plan.request.map(UpdateCheckRequestSummary.init))
            case .background:
                let plan = controller.checkForUpdatesInBackground()
                planActions.append(plan.action.rawValue)
                requests.append(plan.request.map(UpdateCheckRequestSummary.init))
            case let .updateSettings(settings):
                controller.updateSettings(settings)
                planActions.append("updateSettings")
                requests.append(nil)
            }
        }

        return UpdateCheckerControllerMatrixRow(
            id: id,
            initialSettings: UpdateCheckerSettingsSummary(initialSettings),
            actions: actions.map(\.summary),
            planActions: planActions,
            requests: requests,
            finalSettings: UpdateCheckerSettingsSummary(controller.settings),
            lastPlanAction: controller.lastPlan?.action.rawValue,
            events: events
        )
    }
}

private struct UpdateCheckerControllerMatrixFixture: Codable, Equatable {
    let rows: [UpdateCheckerControllerMatrixRow]
}

private struct UpdateCheckerControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialSettings: UpdateCheckerSettingsSummary
    let actions: [String]
    let planActions: [String]
    let requests: [UpdateCheckRequestSummary?]
    let finalSettings: UpdateCheckerSettingsSummary
    let lastPlanAction: String?
    let events: [String]
}

private struct UpdateCheckerSettingsSummary: Codable, Equatable {
    let automaticChecksEnabled: Bool
    let automaticInstallEnabled: Bool

    init(_ settings: UpdateCheckerSettings) {
        self.automaticChecksEnabled = settings.automaticChecksEnabled
        self.automaticInstallEnabled = settings.automaticInstallEnabled
    }
}

private struct UpdateCheckRequestSummary: Codable, Equatable {
    let kind: String
    let currentVersion: String
    let automaticInstallAllowed: Bool

    init(_ request: UpdateCheckRequest) {
        self.kind = request.kind.rawValue
        self.currentVersion = request.currentVersion
        self.automaticInstallAllowed = request.automaticInstallAllowed
    }
}

private enum UpdateCheckerControllerFixtureAction {
    case manual
    case background
    case updateSettings(UpdateCheckerSettings)

    var summary: String {
        switch self {
        case .manual:
            return "manual"
        case .background:
            return "background"
        case let .updateSettings(settings):
            return "updateSettings:\(settings.automaticChecksEnabled):\(settings.automaticInstallEnabled)"
        }
    }
}
