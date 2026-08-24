import XCTest
@testable import MyVibeIslandCore

final class ShortcutRecorderModelsTests: XCTestCase {
    func testShortcutRecorderMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutRecorderMatrixFixture.self,
            from: try FixtureLoader.data("settings/shortcut-recorder-matrix")
        )

        let model = ShortcutRecorderModel()
        let approve = approveSpec()
        let deny = HotKeyRegistrationSpec(
            id: "deny",
            action: .denyPermission,
            keyCombo: KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]),
            scope: .expandedPanel
        )
        let captureCombo = KeyCombo(keyCode: 40, characters: "K", modifiers: [.command, .shift])

        let actual = ShortcutRecorderMatrixFixture(
            beginRows: [
                beginRow(id: "idle-starts", specId: "approve", state: ShortcutRecorderState(), model: model),
                beginRow(
                    id: "same-target-restarts",
                    specId: "approve",
                    state: ShortcutRecorderState(activeSpecId: "approve"),
                    model: model
                ),
                beginRow(
                    id: "different-target-blocked",
                    specId: "deny",
                    state: ShortcutRecorderState(activeSpecId: "approve"),
                    model: model
                ),
            ],
            captureRows: [
                captureRow(
                    id: "inactive-target-ignored",
                    combo: captureCombo,
                    targetSpec: approve,
                    existingSpecs: [approve],
                    state: ShortcutRecorderState(activeSpecId: "deny"),
                    model: model
                ),
                captureRow(
                    id: "escape-cancels",
                    combo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                    targetSpec: approve,
                    existingSpecs: [approve],
                    state: ShortcutRecorderState(activeSpecId: "approve"),
                    model: model
                ),
                captureRow(
                    id: "duplicate-conflicts",
                    combo: deny.keyCombo,
                    targetSpec: approve,
                    existingSpecs: [approve, deny],
                    state: ShortcutRecorderState(activeSpecId: "approve"),
                    model: model
                ),
                captureRow(
                    id: "new-combo-captured",
                    combo: captureCombo,
                    targetSpec: approve,
                    existingSpecs: [approve, deny],
                    state: ShortcutRecorderState(activeSpecId: "approve"),
                    model: model
                ),
            ],
            toggleRows: [
                toggleRow(id: "disable-preserves-combo", isEnabled: false, spec: approve, model: model),
                toggleRow(id: "enable-preserves-combo", isEnabled: true, spec: model.setEnabled(false, for: approve), model: model),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testRecorderStateRoundTripsActiveTargetPendingComboAndConflict() throws {
        let state = ShortcutRecorderState(
            activeSpecId: "approve",
            pendingCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
            conflict: ShortcutRecorderConflict(
                targetSpecId: "approve",
                conflictingSpecId: "deny",
                keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command])
            )
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShortcutRecorderState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertTrue(decoded.isRecording)
        XCTAssertEqual(decoded.displayText, "Cmd-Return")
    }

    func testRecorderAllowsOnlyOneActiveRecordingAtATime() {
        let model = ShortcutRecorderModel()
        let idle = ShortcutRecorderState()
        let first = model.beginRecording(specId: "approve", from: idle)
        let second = model.beginRecording(specId: "deny", from: first.nextState)

        XCTAssertEqual(first.decision, .started)
        XCTAssertEqual(first.nextState.activeSpecId, "approve")
        XCTAssertEqual(second.decision, .alreadyRecording)
        XCTAssertEqual(second.nextState.activeSpecId, "approve")
    }

    func testEscCancelsRecordingWithoutSavingCombo() {
        let model = ShortcutRecorderModel()
        let recording = ShortcutRecorderState(activeSpecId: "approve")

        let result = model.capture(
            KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
            for: approveSpec(),
            existingSpecs: [approveSpec()],
            from: recording
        )

        XCTAssertEqual(result.decision, .cancelled)
        XCTAssertEqual(result.nextState, ShortcutRecorderState())
        XCTAssertNil(result.updatedSpec)
    }

    func testDuplicateComboIsReportedBeforeSave() {
        let model = ShortcutRecorderModel()
        let recording = ShortcutRecorderState(activeSpecId: "approve")
        let duplicateCombo = KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command])
        let deny = HotKeyRegistrationSpec(
            id: "deny",
            action: .denyPermission,
            keyCombo: duplicateCombo,
            scope: .expandedPanel
        )

        let result = model.capture(
            duplicateCombo,
            for: approveSpec(),
            existingSpecs: [approveSpec(), deny],
            from: recording
        )

        XCTAssertEqual(result.decision, .conflict)
        XCTAssertEqual(result.nextState.conflict?.conflictingSpecId, "deny")
        XCTAssertEqual(result.nextState.pendingCombo, duplicateCombo)
        XCTAssertNil(result.updatedSpec)
    }

    func testDisablingShortcutPreservesStoredMapping() {
        let spec = approveSpec()
        let disabled = ShortcutRecorderModel().setEnabled(false, for: spec)

        XCTAssertFalse(disabled.isEnabled)
        XCTAssertEqual(disabled.keyCombo, spec.keyCombo)
        XCTAssertEqual(disabled.action, spec.action)
        XCTAssertEqual(disabled.scope, spec.scope)
    }

    private func approveSpec() -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: "approve",
            action: .approvePermission,
            keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
            scope: .expandedPanel
        )
    }

    private func beginRow(
        id: String,
        specId: String,
        state: ShortcutRecorderState,
        model: ShortcutRecorderModel
    ) -> ShortcutRecorderBeginRow {
        let result = model.beginRecording(specId: specId, from: state)
        return ShortcutRecorderBeginRow(
            id: id,
            decision: result.decision.rawValue,
            nextState: result.nextState.fixture
        )
    }

    private func captureRow(
        id: String,
        combo: KeyCombo,
        targetSpec: HotKeyRegistrationSpec,
        existingSpecs: [HotKeyRegistrationSpec],
        state: ShortcutRecorderState,
        model: ShortcutRecorderModel
    ) -> ShortcutRecorderCaptureRow {
        let result = model.capture(
            combo,
            for: targetSpec,
            existingSpecs: existingSpecs,
            from: state
        )
        return ShortcutRecorderCaptureRow(
            id: id,
            decision: result.decision.rawValue,
            nextState: result.nextState.fixture,
            updatedSpec: result.updatedSpec.map(specFixture)
        )
    }

    private func toggleRow(
        id: String,
        isEnabled: Bool,
        spec: HotKeyRegistrationSpec,
        model: ShortcutRecorderModel
    ) -> ShortcutRecorderToggleRow {
        ShortcutRecorderToggleRow(
            id: id,
            spec: specFixture(model.setEnabled(isEnabled, for: spec))
        )
    }

    private func specFixture(_ spec: HotKeyRegistrationSpec) -> ShortcutSpecFixture {
        ShortcutSpecFixture(
            id: spec.id,
            action: spec.action.rawValue,
            displayText: spec.keyCombo.displayText,
            scope: spec.scope.rawValue,
            isEnabled: spec.isEnabled,
            conflictPolicy: spec.conflictPolicy.rawValue
        )
    }

    private struct ShortcutRecorderMatrixFixture: Codable, Equatable {
        let beginRows: [ShortcutRecorderBeginRow]
        let captureRows: [ShortcutRecorderCaptureRow]
        let toggleRows: [ShortcutRecorderToggleRow]
    }

    private struct ShortcutRecorderBeginRow: Codable, Equatable {
        let id: String
        let decision: String
        let nextState: ShortcutRecorderStateFixture
    }

    private struct ShortcutRecorderCaptureRow: Codable, Equatable {
        let id: String
        let decision: String
        let nextState: ShortcutRecorderStateFixture
        let updatedSpec: ShortcutSpecFixture?
    }

    private struct ShortcutRecorderToggleRow: Codable, Equatable {
        let id: String
        let spec: ShortcutSpecFixture
    }

    fileprivate struct ShortcutRecorderStateFixture: Codable, Equatable {
        let activeSpecId: String?
        let pendingDisplayText: String
        let conflictSpecId: String?
    }

    private struct ShortcutSpecFixture: Codable, Equatable {
        let id: String
        let action: String
        let displayText: String
        let scope: String
        let isEnabled: Bool
        let conflictPolicy: String
    }
}

private extension ShortcutRecorderState {
    var fixture: ShortcutRecorderModelsTests.ShortcutRecorderStateFixture {
        ShortcutRecorderModelsTests.ShortcutRecorderStateFixture(
            activeSpecId: activeSpecId,
            pendingDisplayText: displayText,
            conflictSpecId: conflict?.conflictingSpecId
        )
    }
}
