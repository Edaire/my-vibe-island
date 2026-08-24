import Foundation
import XCTest
@testable import MyVibeIslandCore

final class WorkspaceJumpRunnerTests: XCTestCase {
    private final class RecordingWorkspaceOpener: WorkspaceOpening, @unchecked Sendable {
        private(set) var paths: [String] = []
        private let result: WorkspaceOpenResult

        init(result: WorkspaceOpenResult) {
            self.result = result
        }

        func openWorkspace(path: String) -> WorkspaceOpenResult {
            paths.append(path)
            return result
        }
    }

    private final class RecordingOpenClosure: @unchecked Sendable {
        private(set) var paths: [String] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func open(path: String) -> Bool {
            paths.append(path)
            return shouldSucceed
        }
    }

    private final class RecordingIDELauncher: @unchecked Sendable {
        private(set) var launches: [(command: String, arguments: [String])] = []
        private let shouldSucceed: Bool

        init(shouldSucceed: Bool) {
            self.shouldSucceed = shouldSucceed
        }

        func launch(command: String, arguments: [String]) -> Bool {
            launches.append((command, arguments))
            return shouldSucceed
        }
    }

    func testWorkspaceJumpRunnerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            WorkspaceJumpRunnerMatrixFixture.self,
            from: try FixtureLoader.data("terminal/workspace-jump-runner-matrix")
        )

        let actual = WorkspaceJumpRunnerMatrixFixture(rows: workspaceRunnerCases().map { testCase in
            let workspaceOpener = RecordingWorkspaceOpener(result: testCase.workspaceResult)
            let ideOpener = RecordingWorkspaceOpener(result: testCase.ideResult)
            let result = WorkspaceJumpRunner(
                workspaceOpener: workspaceOpener,
                ideWorkspaceOpener: ideOpener
            ).run(testCase.action)

            return WorkspaceJumpRunnerMatrixRow(
                id: testCase.id,
                actionKind: testCase.action.kind.rawValue,
                handlerId: testCase.action.handlerId,
                status: result.status.rawValue,
                failureReason: result.failureReason?.rawValue,
                diagnosticSummary: result.diagnosticSummary,
                workspaceOpenPaths: workspaceOpener.paths,
                ideOpenPaths: ideOpener.paths
            )
        })

        XCTAssertEqual(actual, expected)
    }

    func testWorkspaceRunnerOpensWorkspaceAction() {
        let opener = RecordingWorkspaceOpener(result: .succeeded("opened /tmp/project"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(kind: .openWorkspace, summary: "open workspace", target: "/tmp/project")
        )

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertNil(result.failureReason)
        XCTAssertEqual(result.diagnosticSummary, "opened /tmp/project")
        XCTAssertEqual(opener.paths, ["/tmp/project"])
    }

    func testWorkspaceRunnerUsesWorkspaceOpenerForGenericWorkspaceHandler() {
        let workspaceOpener = RecordingWorkspaceOpener(result: .succeeded("workspace opened"))
        let ideOpener = RecordingWorkspaceOpener(result: .succeeded("ide opened"))
        let result = WorkspaceJumpRunner(
            workspaceOpener: workspaceOpener,
            ideWorkspaceOpener: ideOpener
        ).run(
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "workspace"
            )
        )

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "workspace opened")
        XCTAssertEqual(workspaceOpener.paths, ["/tmp/project"])
        XCTAssertEqual(ideOpener.paths, [])
    }

    func testWorkspaceRunnerUsesIDEOpenerForIDEWorkspaceHandler() {
        let workspaceOpener = RecordingWorkspaceOpener(result: .succeeded("workspace opened"))
        let ideOpener = RecordingWorkspaceOpener(result: .succeeded("ide opened"))
        let result = WorkspaceJumpRunner(
            workspaceOpener: workspaceOpener,
            ideWorkspaceOpener: ideOpener
        ).run(
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "ide-workspace"
            )
        )

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "ide opened")
        XCTAssertEqual(workspaceOpener.paths, [])
        XCTAssertEqual(ideOpener.paths, ["/tmp/project"])
    }

    func testWorkspaceRunnerUsesIDEOpenerForPerIDEWorkspaceHandler() {
        let workspaceOpener = RecordingWorkspaceOpener(result: .succeeded("workspace opened"))
        let ideOpener = RecordingWorkspaceOpener(result: .succeeded("ide opened"))
        let result = WorkspaceJumpRunner(
            workspaceOpener: workspaceOpener,
            ideWorkspaceOpener: ideOpener
        ).run(
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "cursor-workspace"
            )
        )

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "ide opened")
        XCTAssertEqual(workspaceOpener.paths, [])
        XCTAssertEqual(ideOpener.paths, ["/tmp/project"])
    }

    func testWorkspaceRunnerSingleOpenerInitializerStillHandlesIDEWorkspace() {
        let opener = RecordingWorkspaceOpener(result: .succeeded("shared opened"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "ide-workspace"
            )
        )

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "shared opened")
        XCTAssertEqual(opener.paths, ["/tmp/project"])
    }

    func testWorkspaceRunnerRejectsUnsupportedActionWithoutOpening() {
        let opener = RecordingWorkspaceOpener(result: .succeeded("should not open"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(kind: .openURL, summary: "open URL", target: "codex://threads/t1")
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .unsupportedAction)
        XCTAssertEqual(result.diagnosticSummary, "workspace runner unsupported action: openURL")
        XCTAssertEqual(opener.paths, [])
    }

    func testWorkspaceRunnerRejectsMissingTargetWithoutOpening() {
        let opener = RecordingWorkspaceOpener(result: .succeeded("should not open"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(kind: .openWorkspace, summary: "open workspace")
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "workspace runner missing target")
        XCTAssertEqual(opener.paths, [])
    }

    func testWorkspaceRunnerMapsWorkspaceMissingToMissingTarget() {
        let opener = RecordingWorkspaceOpener(result: .failed(.workspaceMissing, diagnosticSummary: "workspace missing: /tmp/missing"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(kind: .openWorkspace, summary: "open workspace", target: "/tmp/missing")
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertEqual(result.diagnosticSummary, "workspace missing: /tmp/missing")
        XCTAssertEqual(opener.paths, ["/tmp/missing"])
    }

    func testWorkspaceRunnerMapsOpenFailureToExecutionFailed() {
        let opener = RecordingWorkspaceOpener(result: .failed(.openFailed, diagnosticSummary: "open failed: /tmp/project"))
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(kind: .openWorkspace, summary: "open workspace", target: "/tmp/project")
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .executionFailed)
        XCTAssertEqual(result.diagnosticSummary, "open failed: /tmp/project")
        XCTAssertEqual(opener.paths, ["/tmp/project"])
    }

    func testSystemWorkspaceOpenerValidatesMissingAndExistingPaths() throws {
        let existing = try temporaryDirectory()
        let missing = existing.appendingPathComponent("missing")
        let recordingOpen = RecordingOpenClosure(shouldSucceed: true)
        let opener = SystemWorkspaceOpener(recordingOpen.open)

        XCTAssertEqual(opener.openWorkspace(path: "").failureReason, .missingTarget)
        XCTAssertEqual(opener.openWorkspace(path: missing.path).failureReason, .workspaceMissing)

        let success = opener.openWorkspace(path: existing.path)
        XCTAssertEqual(success.status, .succeeded)
        XCTAssertEqual(success.diagnosticSummary, "opened workspace: \(existing.path)")
        XCTAssertEqual(recordingOpen.paths, [existing.path])
    }

    func testSystemWorkspaceOpenerMapsOpenClosureFailure() throws {
        let existing = try temporaryDirectory()
        let opener = SystemWorkspaceOpener { _ in false }

        let result = opener.openWorkspace(path: existing.path)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .openFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to open workspace: \(existing.path)")
    }

    func testSystemWorkspaceOpenerDefaultInitializerExists() throws {
        let opener = SystemWorkspaceOpener()

        XCTAssertEqual(opener.openWorkspace(path: "").failureReason, .missingTarget)
    }

    func testIDEWorkspaceOpenerDefaultCandidatesIncludeJetBrainsLaunchers() {
        XCTAssertTrue(IDEWorkspaceOpener.defaultCandidateCommands.contains("idea"))
        XCTAssertTrue(IDEWorkspaceOpener.defaultCandidateCommands.contains("webstorm"))
    }

    func testIDEWorkspaceOpenerLaunchesFirstAvailableCommandWithReuseWindowArgument() throws {
        let existing = try temporaryDirectory()
        let launcher = RecordingIDELauncher(shouldSucceed: true)
        let opener = IDEWorkspaceOpener(
            candidateCommands: ["code", "cursor"],
            commandResolver: { commands in commands.first { $0 == "cursor" } },
            launch: launcher.launch
        )

        let result = opener.openWorkspace(path: existing.path)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "opened IDE workspace with cursor: \(existing.path)")
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches.first?.command, "cursor")
        XCTAssertEqual(launcher.launches.first?.arguments, ["-r", existing.path])
    }

    func testIDEWorkspaceOpenerLaunchesJetBrainsCommandWithReuseWindowArgument() throws {
        let existing = try temporaryDirectory()
        let launcher = RecordingIDELauncher(shouldSucceed: true)
        let opener = IDEWorkspaceOpener(
            commandResolver: { commands in commands.first { $0 == "idea" } },
            launch: launcher.launch
        )

        let result = opener.openWorkspace(path: existing.path)

        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.diagnosticSummary, "opened IDE workspace with idea: \(existing.path)")
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches.first?.command, "idea")
        XCTAssertEqual(launcher.launches.first?.arguments, ["-r", existing.path])
    }

    func testIDEWorkspaceOpenerReportsMissingCommandWithoutLaunching() throws {
        let existing = try temporaryDirectory()
        let launcher = RecordingIDELauncher(shouldSucceed: true)
        let opener = IDEWorkspaceOpener(
            candidateCommands: ["code", "cursor"],
            commandResolver: { _ in nil },
            launch: launcher.launch
        )

        let result = opener.openWorkspace(path: existing.path)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .dependencyMissing)
        XCTAssertEqual(result.diagnosticSummary, "missing IDE CLI command: code, cursor")
        XCTAssertEqual(launcher.launches.count, 0)
    }

    func testIDEWorkspaceOpenerMapsLaunchFailureToOpenFailed() throws {
        let existing = try temporaryDirectory()
        let opener = IDEWorkspaceOpener(
            candidateCommands: ["code"],
            commandResolver: { _ in "code" },
            launch: RecordingIDELauncher(shouldSucceed: false).launch
        )

        let result = opener.openWorkspace(path: existing.path)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .openFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to open IDE workspace with code: \(existing.path)")
    }

    func testIDEWorkspaceOpenerValidatesMissingTargetAndWorkspace() throws {
        let existing = try temporaryDirectory()
        let missing = existing.appendingPathComponent("missing")
        let opener = IDEWorkspaceOpener(
            candidateCommands: ["code"],
            commandResolver: { _ in "code" },
            launch: RecordingIDELauncher(shouldSucceed: true).launch
        )

        XCTAssertEqual(opener.openWorkspace(path: "").failureReason, .missingTarget)
        XCTAssertEqual(opener.openWorkspace(path: missing.path).failureReason, .workspaceMissing)
    }

    func testWorkspaceRunnerMapsDependencyMissingToRunnerDependencyMissing() {
        let opener = RecordingWorkspaceOpener(
            result: .failed(.dependencyMissing, diagnosticSummary: "missing IDE CLI command: code")
        )
        let result = WorkspaceJumpRunner(opener: opener).run(
            TerminalJumpActionDescription(
                kind: .openWorkspace,
                summary: "open workspace",
                target: "/tmp/project",
                handlerId: "ide-workspace"
            )
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .dependencyMissing)
        XCTAssertEqual(result.diagnosticSummary, "missing IDE CLI command: code")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-workspace-runner-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func workspaceRunnerCases() -> [(
        id: String,
        action: TerminalJumpActionDescription,
        workspaceResult: WorkspaceOpenResult,
        ideResult: WorkspaceOpenResult
    )] {
        [
            (
                id: "generic-workspace-opener",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/project",
                    handlerId: "workspace"
                ),
                workspaceResult: .succeeded("workspace opened"),
                ideResult: .succeeded("ide opened")
            ),
            (
                id: "explicit-ide-workspace-opener",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/project",
                    handlerId: "ide-workspace"
                ),
                workspaceResult: .succeeded("workspace opened"),
                ideResult: .succeeded("ide opened")
            ),
            (
                id: "registry-ide-workspace-opener",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/project",
                    handlerId: "cursor-workspace"
                ),
                workspaceResult: .succeeded("workspace opened"),
                ideResult: .succeeded("ide opened")
            ),
            (
                id: "unsupported-action-no-open",
                action: TerminalJumpActionDescription(
                    kind: .openURL,
                    summary: "open URL",
                    target: "codex://threads/t1"
                ),
                workspaceResult: .succeeded("should not open"),
                ideResult: .succeeded("should not open")
            ),
            (
                id: "missing-target-no-open",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace"
                ),
                workspaceResult: .succeeded("should not open"),
                ideResult: .succeeded("should not open")
            ),
            (
                id: "workspace-missing-maps-to-missing-target",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/missing"
                ),
                workspaceResult: .failed(.workspaceMissing, diagnosticSummary: "workspace missing: /tmp/missing"),
                ideResult: .succeeded("ide opened")
            ),
            (
                id: "ide-dependency-missing-maps-through",
                action: TerminalJumpActionDescription(
                    kind: .openWorkspace,
                    summary: "open workspace",
                    target: "/tmp/project",
                    handlerId: "ide-workspace"
                ),
                workspaceResult: .succeeded("workspace opened"),
                ideResult: .failed(.dependencyMissing, diagnosticSummary: "missing IDE CLI command: code")
            ),
        ]
    }

    private struct WorkspaceJumpRunnerMatrixFixture: Codable, Equatable {
        let rows: [WorkspaceJumpRunnerMatrixRow]
    }

    private struct WorkspaceJumpRunnerMatrixRow: Codable, Equatable {
        let id: String
        let actionKind: String
        let handlerId: String?
        let status: String
        let failureReason: String?
        let diagnosticSummary: String
        let workspaceOpenPaths: [String]
        let ideOpenPaths: [String]
    }
}
