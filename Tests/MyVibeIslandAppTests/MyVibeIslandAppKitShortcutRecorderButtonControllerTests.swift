import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitShortcutRecorderButtonControllerTests: XCTestCase {
    @MainActor
    func testShortcutRecorderButtonControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutRecorderButtonControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/shortcut-recorder-button-controller-matrix")
        )
        let deny = HotKeyRegistrationSpec(
            id: "deny",
            action: .denyPermission,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]),
            scope: .expandedPanel
        )

        let actual = ShortcutRecorderButtonControllerMatrixFixture(rows: [
            row(id: "capture-shortcut", specs: [Self.approveSpec], actions: [.begin("approve"), .capture(MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]))]),
            row(id: "capture-conflict", specs: [Self.approveSpec, deny], actions: [.begin("approve"), .capture(deny.keyCombo)]),
            row(id: "disable-without-remapping", specs: [Self.approveSpec], actions: [.setEnabled(false, "approve")])
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerBeginsRecordingAndSavesCapturedShortcutThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutRecorderButtonController(
            specs: [Self.approveSpec],
            renderState: { state in
                events.append("render:\(state.activeSpecId ?? "none"):\(state.displayText)")
            },
            saveSpec: { spec in
                events.append("save:\(spec.id):\(spec.keyCombo.displayText)")
            }
        )

        let started = controller.beginRecording(specId: "approve")
        let captured = controller.capture(MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]))

        XCTAssertEqual(started.decision, .started)
        XCTAssertEqual(captured.decision, .captured)
        XCTAssertEqual(controller.state, ShortcutRecorderState())
        XCTAssertEqual(controller.specs.first?.keyCombo.displayText, "Cmd-Delete")
        XCTAssertEqual(events, [
            "render:approve:",
            "save:approve:Cmd-Delete",
            "render:none:"
        ])
    }

    @MainActor
    func testControllerRendersConflictWithoutSavingSpec() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutRecorderButtonController(
            specs: [
                Self.approveSpec,
                HotKeyRegistrationSpec(
                    id: "deny",
                    action: .denyPermission,
                    keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]),
                    scope: .expandedPanel
                ),
            ],
            renderState: { state in
                events.append("render:\(state.conflict?.conflictingSpecId ?? "none"):\(state.displayText)")
            },
            saveSpec: { spec in
                events.append("save:\(spec.id)")
            }
        )

        _ = controller.beginRecording(specId: "approve")
        let conflict = controller.capture(MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]))

        XCTAssertEqual(conflict.decision, .conflict)
        XCTAssertEqual(controller.state.conflict?.conflictingSpecId, "deny")
        XCTAssertEqual(controller.specs.first?.keyCombo.displayText, "Cmd-Return")
        XCTAssertEqual(events, [
            "render:none:",
            "render:deny:Cmd-Delete"
        ])
    }

    @MainActor
    func testControllerTogglesShortcutEnabledWithoutLosingMapping() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutRecorderButtonController(
            specs: [Self.approveSpec],
            saveSpec: { spec in
                events.append("save:\(spec.id):\(spec.isEnabled):\(spec.keyCombo.displayText)")
            }
        )

        let disabled = controller.setEnabled(false, specId: "approve")

        XCTAssertFalse(disabled?.isEnabled ?? true)
        XCTAssertEqual(disabled?.keyCombo.displayText, "Cmd-Return")
        XCTAssertEqual(controller.specs.first?.isEnabled, false)
        XCTAssertEqual(events, ["save:approve:false:Cmd-Return"])
    }

    @MainActor
    func testControllerPublishesLastRecorderResultForOrchestration() {
        let controller = MyVibeIslandAppKitShortcutRecorderButtonController(
            specs: [Self.approveSpec],
            renderState: { _ in },
            saveSpec: { _ in }
        )

        _ = controller.beginRecording(specId: "approve")
        _ = controller.capture(MyVibeIslandCore.KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]))

        XCTAssertEqual(controller.lastResult?.decision, .captured)
        XCTAssertEqual(controller.lastResult?.updatedSpec?.id, "approve")
        XCTAssertEqual(controller.lastResult?.updatedSpec?.keyCombo.displayText, "Cmd-Delete")
    }

    private static let approveSpec = HotKeyRegistrationSpec(
        id: "approve",
        action: .approvePermission,
        keyCombo: MyVibeIslandCore.KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
        scope: .expandedPanel
    )

    @MainActor
    private func row(
        id: String,
        specs: [HotKeyRegistrationSpec],
        actions: [ShortcutRecorderButtonControllerFixtureAction]
    ) -> ShortcutRecorderButtonControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitShortcutRecorderButtonController(
            specs: specs,
            renderState: { events.append("render:\($0.activeSpecId ?? "none"):\($0.conflict?.conflictingSpecId ?? "none"):\($0.displayText)") },
            saveSpec: { events.append("save:\($0.id):\($0.isEnabled):\($0.keyCombo.displayText)") }
        )
        var outcomes: [String] = []

        for action in actions {
            switch action {
            case let .begin(specId): outcomes.append("result:\(controller.beginRecording(specId: specId).decision.rawValue)")
            case let .capture(keyCombo): outcomes.append("result:\(controller.capture(keyCombo).decision.rawValue)")
            case let .setEnabled(enabled, specId):
                let spec = controller.setEnabled(enabled, specId: specId)
                outcomes.append("enabled:\(spec?.isEnabled.description ?? "nil")")
            }
        }

        return ShortcutRecorderButtonControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            outcomes: outcomes,
            state: ShortcutRecorderStateSummary(controller.state),
            specs: controller.specs.map(ShortcutRecorderSpecSummary.init),
            lastResultDecision: controller.lastResult?.decision.rawValue,
            events: events
        )
    }
}

private enum ShortcutRecorderButtonControllerFixtureAction {
    case begin(String)
    case capture(MyVibeIslandCore.KeyCombo)
    case setEnabled(Bool, String)

    var summary: String {
        switch self {
        case let .begin(specId): "begin:\(specId)"
        case let .capture(keyCombo): "capture:\(keyCombo.displayText)"
        case let .setEnabled(enabled, specId): "setEnabled:\(specId):\(enabled)"
        }
    }
}

private struct ShortcutRecorderButtonControllerMatrixFixture: Codable, Equatable {
    let rows: [ShortcutRecorderButtonControllerMatrixRow]
}

private struct ShortcutRecorderButtonControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let outcomes: [String]
    let state: ShortcutRecorderStateSummary
    let specs: [ShortcutRecorderSpecSummary]
    let lastResultDecision: String?
    let events: [String]
}

private struct ShortcutRecorderStateSummary: Codable, Equatable {
    let activeSpecId: String?
    let displayText: String
    let conflictingSpecId: String?

    init(_ state: ShortcutRecorderState) {
        self.activeSpecId = state.activeSpecId
        self.displayText = state.displayText
        self.conflictingSpecId = state.conflict?.conflictingSpecId
    }
}

private struct ShortcutRecorderSpecSummary: Codable, Equatable {
    let id: String
    let isEnabled: Bool
    let displayText: String

    init(_ spec: HotKeyRegistrationSpec) {
        self.id = spec.id
        self.isEnabled = spec.isEnabled
        self.displayText = spec.keyCombo.displayText
    }
}
