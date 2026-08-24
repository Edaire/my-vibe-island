import XCTest
@testable import MyVibeIslandCore

final class RemoteSetupGuideTests: XCTestCase {
    func testRemoteSetupGuideMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteSetupGuideMatrixFixture.self,
            from: try FixtureLoader.data("remote/setup-guide-matrix")
        )

        let dockerSetup = DockerSidecarSetup(
            hostId: "devbox",
            containerPlatform: "docker",
            sidecarCommand: "docker run --rm -v ~/.config/my-vibe-island:/config my-vibe-island-sidecar",
            persistenceHint: "mount ~/.config/my-vibe-island",
            rerunHint: "rerun after container restart"
        )
        let podmanSetup = DockerSidecarSetup(
            hostId: "labbox",
            containerPlatform: "podman",
            sidecarCommand: "podman run --rm my-vibe-island-sidecar",
            persistenceHint: nil,
            rerunHint: nil
        )
        let manualGuide = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/My Vibe Island.app/Contents/Resources/remote-hook",
            remoteDestination: "~/.local/bin/my-vibe-island-hook",
            transportInstructions: [
                "copy remote-hook to removable media",
                "move remote-hook from removable media to ~/.local/bin/my-vibe-island-hook"
            ],
            remoteCommands: [
                "mkdir -p ~/.local/bin",
                "chmod +x ~/.local/bin/my-vibe-island-hook"
            ],
            deployVerificationCommand: "~/.local/bin/my-vibe-island-hook --version"
        )

        let actual = RemoteSetupGuideMatrixFixture(rows: [
            row(id: "docker-sidecar", steps: dockerSetup.commandSteps, canExecuteAutomatically: dockerSetup.canExecuteAutomatically),
            row(id: "podman-sidecar", steps: podmanSetup.commandSteps, canExecuteAutomatically: podmanSetup.canExecuteAutomatically),
            row(id: "manual-air-gapped-install", steps: manualGuide.installPlan.steps, canExecuteAutomatically: manualGuide.installPlan.canExecuteAutomatically),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDockerSidecarSetupRoundTripsCopyableInstructions() throws {
        let setup = DockerSidecarSetup(
            hostId: "devbox",
            containerPlatform: "docker",
            sidecarCommand: "docker run my-vibe-island-sidecar",
            persistenceHint: "mount the config directory",
            rerunHint: "rerun after container restart"
        )

        let decoded = try JSONDecoder().decode(DockerSidecarSetup.self, from: try JSONEncoder().encode(setup))

        XCTAssertEqual(decoded, setup)
        XCTAssertTrue(decoded.requiresUserRunCommand)
    }

    func testDockerSidecarSetupBuildsUserRunCommandStepsWithoutExecution() throws {
        let setup = DockerSidecarSetup(
            hostId: "devbox",
            containerPlatform: "podman",
            sidecarCommand: "podman run --rm my-vibe-island-sidecar",
            persistenceHint: "mount ~/.config/my-vibe-island",
            rerunHint: "rerun after replacing the container image"
        )

        XCTAssertEqual(setup.commandSteps, [
            RemoteSetupCommandStep(
                kind: .sidecar,
                body: "podman run --rm my-vibe-island-sidecar",
                note: "podman sidecar for devbox"
            )
        ])
        XCTAssertTrue(setup.commandSteps.allSatisfy(\.requiresUserRun))
        XCTAssertFalse(setup.canExecuteAutomatically)
    }

    func testManualRemoteInstallGuideRoundTripsCopyableCommands() throws {
        let guide = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/My Vibe Island.app/Contents/Resources/remote-hook",
            remoteDestination: "~/.local/bin/my-vibe-island-hook",
            transportInstructions: ["copy the helper to the remote host"],
            remoteCommands: ["chmod +x ~/.local/bin/my-vibe-island-hook"],
            deployVerificationCommand: "~/.local/bin/my-vibe-island-hook --version"
        )

        let decoded = try JSONDecoder().decode(ManualRemoteInstallGuide.self, from: try JSONEncoder().encode(guide))

        XCTAssertEqual(decoded, guide)
        XCTAssertTrue(decoded.instructionsAreCopyable)
    }

    func testManualRemoteInstallGuideBuildsAirGappedUserRunInstallPlan() throws {
        let guide = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/My Vibe Island.app/Contents/Resources/remote-hook",
            remoteDestination: "~/.local/bin/my-vibe-island-hook",
            transportInstructions: [
                "copy remote-hook to removable media",
                "move remote-hook from removable media to ~/.local/bin/my-vibe-island-hook"
            ],
            remoteCommands: [
                "mkdir -p ~/.local/bin",
                "chmod +x ~/.local/bin/my-vibe-island-hook"
            ],
            deployVerificationCommand: "~/.local/bin/my-vibe-island-hook --version"
        )

        XCTAssertEqual(guide.installPlan.steps, [
            RemoteSetupCommandStep(
                kind: .transport,
                body: "copy remote-hook to removable media",
                note: "transport linux-arm64 helper from /Applications/My Vibe Island.app/Contents/Resources/remote-hook"
            ),
            RemoteSetupCommandStep(
                kind: .transport,
                body: "move remote-hook from removable media to ~/.local/bin/my-vibe-island-hook",
                note: "transport linux-arm64 helper from /Applications/My Vibe Island.app/Contents/Resources/remote-hook"
            ),
            RemoteSetupCommandStep(
                kind: .remoteCommand,
                body: "mkdir -p ~/.local/bin",
                note: "run on remote host"
            ),
            RemoteSetupCommandStep(
                kind: .remoteCommand,
                body: "chmod +x ~/.local/bin/my-vibe-island-hook",
                note: "run on remote host"
            ),
            RemoteSetupCommandStep(
                kind: .verification,
                body: "~/.local/bin/my-vibe-island-hook --version",
                note: "verify ~/.local/bin/my-vibe-island-hook"
            )
        ])
        XCTAssertTrue(guide.installPlan.steps.allSatisfy(\.requiresUserRun))
        XCTAssertFalse(guide.installPlan.canExecuteAutomatically)
    }

    private func row(
        id: String,
        steps: [RemoteSetupCommandStep],
        canExecuteAutomatically: Bool
    ) -> RemoteSetupGuideRowFixture {
        RemoteSetupGuideRowFixture(
            id: id,
            canExecuteAutomatically: canExecuteAutomatically,
            allRequireUserRun: steps.allSatisfy(\.requiresUserRun),
            steps: steps.map {
                RemoteSetupCommandStepFixture(
                    kind: $0.kind.rawValue,
                    body: $0.body,
                    note: $0.note,
                    requiresUserRun: $0.requiresUserRun
                )
            }
        )
    }

    private struct RemoteSetupGuideMatrixFixture: Codable, Equatable {
        let rows: [RemoteSetupGuideRowFixture]
    }

    private struct RemoteSetupGuideRowFixture: Codable, Equatable {
        let id: String
        let canExecuteAutomatically: Bool
        let allRequireUserRun: Bool
        let steps: [RemoteSetupCommandStepFixture]
    }

    private struct RemoteSetupCommandStepFixture: Codable, Equatable {
        let kind: String
        let body: String
        let note: String
        let requiresUserRun: Bool
    }
}
