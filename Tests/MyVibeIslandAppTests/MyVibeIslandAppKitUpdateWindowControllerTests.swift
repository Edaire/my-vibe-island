import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitUpdateWindowControllerTests: XCTestCase {
    @MainActor
    func testUpdateWindowControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UpdateWindowControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/update-window-controller-matrix")
        )
        let actual = UpdateWindowControllerMatrixFixture(rows: [
            row(id: "downloaded-critical-update-remind-later") { controller in
                controller.checkForUpdates()
                controller.foundUpdate(
                    version: "2.0.0",
                    critical: true,
                    informationOnly: true,
                    majorUpgrade: true,
                    alreadyDownloaded: true,
                    notes: [ReleaseNotesSection(title: "Security", summary: "Important fixes", category: .security, severity: .critical)]
                )
                controller.remindLater()
            },
            row(id: "manual-check-failure") { controller in
                controller.checkForUpdates()
                controller.fail("network unavailable")
            }
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerTracksManualCheckFoundUpdateAndDismissal() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitUpdateWindowController(
            snapshot: UpdatePresentationSnapshot(currentVersion: "1.0.0"),
            presentWindow: { viewModel in
                events.append("present:\(viewModel.snapshot.phase.rawValue):\(viewModel.primaryAction.rawValue)")
            },
            dismissWindow: {
                events.append("dismiss")
            }
        )

        controller.checkForUpdates()
        controller.foundUpdate(version: "2.0.0", notes: [
            ReleaseNotesSection(title: "New", summary: "Feature")
        ])
        controller.skipVersion()

        XCTAssertEqual(controller.snapshot.phase, .skipped)
        XCTAssertEqual(controller.snapshot.skippedVersion, "2.0.0")
        XCTAssertEqual(events, [
            "present:checking:none",
            "present:available:downloadAndInstall",
            "dismiss"
        ])
    }

    @MainActor
    func testControllerPublishesLastUpdatePresentationPlanForOrchestration() {
        let controller = MyVibeIslandAppKitUpdateWindowController(
            snapshot: UpdatePresentationSnapshot(currentVersion: "1.0.0"),
            presentWindow: { _ in },
            dismissWindow: {}
        )

        controller.foundUpdate(version: "2.0.0")

        XCTAssertEqual(controller.lastPlan?.presentedAction, .showUpdateWindow)
        XCTAssertEqual(controller.lastPlan?.nextSnapshot.newVersion, "2.0.0")
    }

    @MainActor
    private func row(
        id: String,
        perform: @MainActor (MyVibeIslandAppKitUpdateWindowController) -> Void
    ) -> UpdateWindowControllerMatrixRow {
        var events: [String] = []
        var presentations: [UpdateWindowPresentationSummary] = []
        let controller = MyVibeIslandAppKitUpdateWindowController(
            snapshot: UpdatePresentationSnapshot(currentVersion: "1.0.0"),
            presentWindow: { viewModel in
                events.append("present:\(viewModel.snapshot.phase.rawValue):\(viewModel.primaryAction.rawValue)")
                presentations.append(UpdateWindowPresentationSummary(viewModel))
            },
            dismissWindow: {
                events.append("dismiss")
            }
        )

        perform(controller)

        return UpdateWindowControllerMatrixRow(
            id: id,
            phase: controller.snapshot.phase.rawValue,
            newVersion: controller.snapshot.newVersion,
            skippedVersion: controller.snapshot.skippedVersion,
            errorHint: controller.snapshot.errorHint,
            releaseNotesCount: controller.snapshot.releaseNotesSections.count,
            lastPresentedAction: controller.lastPlan?.presentedAction.rawValue,
            presentations: presentations,
            events: events
        )
    }
}

private struct UpdateWindowControllerMatrixFixture: Codable, Equatable {
    let rows: [UpdateWindowControllerMatrixRow]
}

private struct UpdateWindowControllerMatrixRow: Codable, Equatable {
    let id: String
    let phase: String
    let newVersion: String?
    let skippedVersion: String?
    let errorHint: String?
    let releaseNotesCount: Int
    let lastPresentedAction: String?
    let presentations: [UpdateWindowPresentationSummary]
    let events: [String]
}

private struct UpdateWindowPresentationSummary: Codable, Equatable {
    let phase: String
    let primaryAction: String
    let secondaryActions: [String]
    let pillVisible: Bool
    let pillLabel: String
    let pillInstallReady: Bool
    let critical: Bool
    let informationOnly: Bool
    let majorUpgrade: Bool
    let errorHint: String?

    init(_ viewModel: UpdatePresentationViewModel) {
        phase = viewModel.snapshot.phase.rawValue
        primaryAction = viewModel.primaryAction.rawValue
        secondaryActions = viewModel.secondaryActions.map(\.rawValue)
        pillVisible = viewModel.pill.visible
        pillLabel = viewModel.pill.label
        pillInstallReady = viewModel.pill.installReady
        critical = viewModel.snapshot.isCritical
        informationOnly = viewModel.snapshot.isInformationOnly
        majorUpgrade = viewModel.snapshot.isMajorUpgrade
        errorHint = viewModel.snapshot.errorHint
    }
}
