import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRemoteSetupGuideControllerTests: XCTestCase {
    @MainActor
    func testRemoteSetupGuideControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteSetupGuideControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/remote-setup-guide-controller-matrix")
        )
        let sidecar = DockerSidecarSetup(
            hostId: "devbox",
            containerPlatform: "docker",
            sidecarCommand: "docker run my-vibe-island-sidecar",
            persistenceHint: "mount config",
            rerunHint: "rerun after restart"
        )
        let manual = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/My Vibe Island.app/Contents/Resources/remote-hook",
            remoteDestination: "~/.local/bin/my-vibe-island-hook",
            transportInstructions: ["copy the helper"],
            remoteCommands: ["chmod +x ~/.local/bin/my-vibe-island-hook"],
            deployVerificationCommand: "~/.local/bin/my-vibe-island-hook --version"
        )

        let actual = RemoteSetupGuideControllerMatrixFixture(rows: [
            row(id: "present-both-guides", initialSidecar: nil, initialManual: nil, presentSidecar: sidecar, presentManual: manual, clearAtEnd: false),
            row(id: "clear-existing-guides", initialSidecar: sidecar, initialManual: manual, presentSidecar: nil, presentManual: nil, clearAtEnd: true)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testPresentDockerSidecarSetupPublishesCopyableSetup() {
        var published: [DockerSidecarSetup] = []
        let controller = MyVibeIslandAppKitRemoteSetupGuideController(
            publishSidecarSetup: { setup in
                published.append(setup)
            }
        )
        let setup = DockerSidecarSetup(
            hostId: "devbox",
            containerPlatform: "docker",
            sidecarCommand: "docker run my-vibe-island-sidecar",
            persistenceHint: "mount config",
            rerunHint: "rerun after restart"
        )

        let presented = controller.present(sidecarSetup: setup)

        XCTAssertEqual(presented, setup)
        XCTAssertEqual(controller.lastSidecarSetup, setup)
        XCTAssertTrue(controller.requiresUserRunCommand)
        XCTAssertEqual(published, [setup])
    }

    @MainActor
    func testPresentManualInstallGuidePublishesCopyableGuide() {
        var published: [ManualRemoteInstallGuide] = []
        let controller = MyVibeIslandAppKitRemoteSetupGuideController(
            publishManualGuide: { guide in
                published.append(guide)
            }
        )
        let guide = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/My Vibe Island.app/Contents/Resources/remote-hook",
            remoteDestination: "~/.local/bin/my-vibe-island-hook",
            transportInstructions: ["copy the helper"],
            remoteCommands: ["chmod +x ~/.local/bin/my-vibe-island-hook"],
            deployVerificationCommand: "~/.local/bin/my-vibe-island-hook --version"
        )

        let presented = controller.present(manualGuide: guide)

        XCTAssertEqual(presented, guide)
        XCTAssertEqual(controller.lastManualGuide, guide)
        XCTAssertTrue(controller.instructionsAreCopyable)
        XCTAssertEqual(published, [guide])
    }

    @MainActor
    func testClearRemovesGuidesWithoutPublishingCommands() {
        var sidecarPublishCount = 0
        var manualPublishCount = 0
        let controller = MyVibeIslandAppKitRemoteSetupGuideController(
            lastSidecarSetup: DockerSidecarSetup(
                hostId: "devbox",
                containerPlatform: "docker",
                sidecarCommand: "docker run my-vibe-island-sidecar"
            ),
            lastManualGuide: ManualRemoteInstallGuide(
                platform: "linux-arm64",
                localBinaryPath: "/local/hook",
                remoteDestination: "/remote/hook",
                transportInstructions: ["copy"],
                remoteCommands: ["chmod"],
                deployVerificationCommand: "/remote/hook --version"
            ),
            publishSidecarSetup: { _ in sidecarPublishCount += 1 },
            publishManualGuide: { _ in manualPublishCount += 1 }
        )

        controller.clear()

        XCTAssertNil(controller.lastSidecarSetup)
        XCTAssertNil(controller.lastManualGuide)
        XCTAssertFalse(controller.requiresUserRunCommand)
        XCTAssertFalse(controller.instructionsAreCopyable)
        XCTAssertEqual(sidecarPublishCount, 0)
        XCTAssertEqual(manualPublishCount, 0)
    }

    @MainActor
    private func row(
        id: String,
        initialSidecar: DockerSidecarSetup?,
        initialManual: ManualRemoteInstallGuide?,
        presentSidecar: DockerSidecarSetup?,
        presentManual: ManualRemoteInstallGuide?,
        clearAtEnd: Bool
    ) -> RemoteSetupGuideControllerMatrixRow {
        var sidecarEvents: [DockerSidecarSetup] = []
        var manualEvents: [ManualRemoteInstallGuide] = []
        let controller = MyVibeIslandAppKitRemoteSetupGuideController(
            lastSidecarSetup: initialSidecar,
            lastManualGuide: initialManual,
            publishSidecarSetup: { sidecarEvents.append($0) },
            publishManualGuide: { manualEvents.append($0) }
        )

        if let presentSidecar { controller.present(sidecarSetup: presentSidecar) }
        if let presentManual { controller.present(manualGuide: presentManual) }
        if clearAtEnd { controller.clear() }

        return RemoteSetupGuideControllerMatrixRow(
            id: id,
            finalSidecar: controller.lastSidecarSetup,
            finalManual: controller.lastManualGuide,
            requiresUserRunCommand: controller.requiresUserRunCommand,
            instructionsAreCopyable: controller.instructionsAreCopyable,
            sidecarEvents: sidecarEvents,
            manualEvents: manualEvents
        )
    }
}

private struct RemoteSetupGuideControllerMatrixFixture: Codable, Equatable {
    let rows: [RemoteSetupGuideControllerMatrixRow]
}

private struct RemoteSetupGuideControllerMatrixRow: Codable, Equatable {
    let id: String
    let finalSidecar: DockerSidecarSetup?
    let finalManual: ManualRemoteInstallGuide?
    let requiresUserRunCommand: Bool
    let instructionsAreCopyable: Bool
    let sidecarEvents: [DockerSidecarSetup]
    let manualEvents: [ManualRemoteInstallGuide]
}
