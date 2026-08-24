import XCTest
@testable import MyVibeIslandCore

final class UpdatePresentationModelsTests: XCTestCase {
    func testUpdatePresentationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UpdatePresentationMatrixFixture.self,
            from: try FixtureLoader.data("runtime/update-presentation-matrix")
        )
        let coordinator = UpdatePresentationCoordinator()
        let idle = UpdatePresentationSnapshot(currentVersion: "1.0.0")
        let available = UpdatePresentationSnapshot(
            currentVersion: "1.0.0",
            newVersion: "2.0.0",
            phase: .available,
            isCritical: false,
            isMajorUpgrade: true,
            releaseNotesSections: [
                ReleaseNotesSection(title: "Highlights", summary: "New shell polish", items: ["Better menu state"])
            ]
        )
        let criticalAvailable = UpdatePresentationSnapshot(
            currentVersion: "1.0.0",
            newVersion: "2.1.0",
            phase: .available,
            isCritical: true
        )

        let actual = UpdatePresentationMatrixFixture(rows: [
            UpdatePresentationMatrixRow(
                id: "manual-check",
                plan: coordinator.plan(.startManualCheck, from: idle)
            ),
            UpdatePresentationMatrixRow(
                id: "found-available-update",
                plan: coordinator.plan(
                    .foundUpdate(
                        version: "2.0.0",
                        critical: false,
                        informationOnly: false,
                        majorUpgrade: true,
                        alreadyDownloaded: false,
                        notes: available.releaseNotesSections
                    ),
                    from: idle
                )
            ),
            UpdatePresentationMatrixRow(
                id: "found-downloaded-update",
                plan: coordinator.plan(
                    .foundUpdate(
                        version: "2.0.1",
                        critical: false,
                        informationOnly: false,
                        majorUpgrade: false,
                        alreadyDownloaded: true,
                        notes: []
                    ),
                    from: idle
                )
            ),
            UpdatePresentationMatrixRow(
                id: "download-progress-clamped",
                plan: coordinator.plan(
                    .updateDownloadProgress(downloadedLength: 175, expectedContentLength: 100),
                    from: available
                )
            ),
            UpdatePresentationMatrixRow(
                id: "ready-to-install",
                plan: coordinator.plan(.readyToInstall, from: available)
            ),
            UpdatePresentationMatrixRow(
                id: "critical-secondary-actions",
                plan: UpdatePresentationPlan(nextSnapshot: criticalAvailable)
            ),
            UpdatePresentationMatrixRow(
                id: "skip-version",
                plan: coordinator.plan(.skipVersion, from: available)
            ),
            UpdatePresentationMatrixRow(
                id: "remind-later",
                plan: coordinator.plan(.remindLater, from: available)
            ),
            UpdatePresentationMatrixRow(
                id: "failure",
                plan: coordinator.plan(.fail("feed unavailable"), from: idle)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testAvailableUpdateBuildsWindowActionsAndVisiblePill() {
        let coordinator = UpdatePresentationCoordinator()

        let plan = coordinator.plan(
            .foundUpdate(
                version: "2.0.0",
                critical: false,
                informationOnly: false,
                majorUpgrade: true,
                alreadyDownloaded: false,
                notes: [
                    ReleaseNotesSection(title: "Highlights", summary: "New shell polish", items: ["Better menu state"])
                ]
            ),
            from: UpdatePresentationSnapshot(currentVersion: "1.0.0")
        )
        let viewModel = UpdatePresentationViewModel(snapshot: plan.nextSnapshot)

        XCTAssertEqual(plan.nextSnapshot.phase, .available)
        XCTAssertEqual(plan.presentedAction, .showUpdateWindow)
        XCTAssertEqual(viewModel.primaryAction, .downloadAndInstall)
        XCTAssertEqual(viewModel.secondaryActions, [.remindLater, .skipVersion])
        XCTAssertEqual(viewModel.pill, UpdateAvailablePill(visible: true, label: "Update 2.0.0", targetVersion: "2.0.0", installReady: false, action: .openUpdateWindow))
    }

    func testDownloadProgressIsClampedToDisplayRange() {
        let snapshot = UpdatePresentationSnapshot(
            currentVersion: "1.0.0",
            newVersion: "2.0.0",
            phase: .downloading,
            expectedContentLength: 100,
            downloadedLength: 175
        )

        let viewModel = UpdatePresentationViewModel(snapshot: snapshot)

        XCTAssertEqual(viewModel.progressFraction, 1.0)
        XCTAssertEqual(viewModel.primaryAction, .none)
        XCTAssertEqual(viewModel.pill.installReady, false)
    }

    func testReadyToInstallUsesInstallRelaunchActionAndReadyPill() {
        let coordinator = UpdatePresentationCoordinator()
        let available = UpdatePresentationSnapshot(currentVersion: "1.0.0", newVersion: "2.0.0", phase: .available)

        let plan = coordinator.plan(.readyToInstall, from: available)
        let viewModel = UpdatePresentationViewModel(snapshot: plan.nextSnapshot)

        XCTAssertEqual(plan.nextSnapshot.phase, .readyToInstall)
        XCTAssertEqual(viewModel.primaryAction, .installAndRelaunch)
        XCTAssertEqual(viewModel.secondaryActions, [.remindLater])
        XCTAssertEqual(viewModel.pill.installReady, true)
        XCTAssertEqual(viewModel.pill.action, .installAndRelaunch)
    }

    func testSkipAndRemindLaterRespectVersionState() {
        let coordinator = UpdatePresentationCoordinator()
        let available = UpdatePresentationSnapshot(currentVersion: "1.0.0", newVersion: "2.0.0", phase: .available)

        let skipped = coordinator.plan(.skipVersion, from: available)
        XCTAssertEqual(skipped.nextSnapshot.phase, .skipped)
        XCTAssertEqual(skipped.nextSnapshot.skippedVersion, "2.0.0")
        XCTAssertEqual(skipped.presentedAction, .dismissUpdateWindow)

        let reminded = coordinator.plan(.remindLater, from: available)
        XCTAssertEqual(reminded.nextSnapshot.phase, .idle)
        XCTAssertNil(reminded.nextSnapshot.skippedVersion)
        XCTAssertEqual(reminded.presentedAction, .dismissUpdateWindow)
    }

    func testFailureShowsRetryActionAndErrorHint() {
        let coordinator = UpdatePresentationCoordinator()

        let plan = coordinator.plan(.fail("feed unavailable"), from: UpdatePresentationSnapshot(currentVersion: "1.0.0"))
        let viewModel = UpdatePresentationViewModel(snapshot: plan.nextSnapshot)

        XCTAssertEqual(plan.nextSnapshot.phase, .failed)
        XCTAssertEqual(plan.nextSnapshot.errorHint, "feed unavailable")
        XCTAssertEqual(viewModel.primaryAction, .checkAgain)
        XCTAssertEqual(viewModel.secondaryActions, [])
        XCTAssertFalse(viewModel.pill.visible)
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let snapshot = UpdatePresentationSnapshot(
            currentVersion: "1.0.0",
            newVersion: "2.0.0",
            previousVersion: "0.9.0",
            phase: .available,
            isCritical: true,
            isInformationOnly: false,
            isMajorUpgrade: true,
            isAlreadyDownloaded: false,
            expectedContentLength: 42,
            downloadedLength: 21,
            skippedVersion: nil,
            willInstallOnQuit: false,
            isPostUpdateRestart: true,
            releaseNotesSections: [
                ReleaseNotesSection(title: "Fixes", summary: "Small fixes", items: ["One"], category: .fix, severity: .normal)
            ],
            errorHint: nil
        )

        let decoded = try JSONDecoder().decode(
            UpdatePresentationSnapshot.self,
            from: try JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
    }
}

private struct UpdatePresentationMatrixFixture: Codable, Equatable {
    let rows: [UpdatePresentationMatrixRow]
}

private struct UpdatePresentationMatrixRow: Codable, Equatable {
    let id: String
    let phase: UpdatePhase
    let targetVersion: String?
    let isCritical: Bool
    let isMajorUpgrade: Bool
    let isAlreadyDownloaded: Bool
    let skippedVersion: String?
    let errorHint: String?
    let presentedAction: UpdatePresentedAction
    let progressFraction: Double?
    let primaryAction: UpdatePresentationAction
    let secondaryActions: [UpdatePresentationAction]
    let pill: UpdateAvailablePill
    let releaseNoteTitles: [String]

    init(id: String, plan: UpdatePresentationPlan) {
        self.id = id
        let snapshot = plan.nextSnapshot
        let viewModel = UpdatePresentationViewModel(snapshot: snapshot)
        phase = snapshot.phase
        targetVersion = snapshot.newVersion
        isCritical = snapshot.isCritical
        isMajorUpgrade = snapshot.isMajorUpgrade
        isAlreadyDownloaded = snapshot.isAlreadyDownloaded
        skippedVersion = snapshot.skippedVersion
        errorHint = snapshot.errorHint
        presentedAction = plan.presentedAction
        progressFraction = viewModel.progressFraction
        primaryAction = viewModel.primaryAction
        secondaryActions = viewModel.secondaryActions
        pill = viewModel.pill
        releaseNoteTitles = snapshot.releaseNotesSections.map(\.title)
    }
}
