import XCTest
@testable import MyVibeIslandCore

final class CarbonHotKeyControllerModelsTests: XCTestCase {
    func testCarbonHotKeyControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CarbonHotKeyControllerMatrixFixture.self,
            from: try FixtureLoader.data("settings/carbon-hotkey-controller-matrix")
        )
        let existing = ref(id: "toggle", carbonId: 7, keyCode: 49, characters: "Space")

        let actual = CarbonHotKeyControllerMatrixFixture(rows: [
            CarbonHotKeyControllerMatrixRow(
                id: "fresh-registration",
                registrationPlan: CarbonHotKeyController().planRegistration([
                    spec(id: "toggle", keyCode: 49),
                    spec(id: "jump", keyCode: 37, characters: "L", action: .jumpToTerminal),
                ])
            ),
            CarbonHotKeyControllerMatrixRow(
                id: "reuse-and-reject",
                registrationPlan: CarbonHotKeyController().planRegistration(
                    [
                        spec(id: "toggle", keyCode: 49),
                        spec(id: "jump", keyCode: 37, characters: "L", action: .jumpToTerminal),
                    ],
                    existingRefs: [existing],
                    rejectedSpecIds: ["jump"]
                )
            ),
            CarbonHotKeyControllerMatrixRow(
                id: "unregister-one",
                unregistrationPlan: CarbonHotKeyController().planUnregistration(
                    ids: ["toggle"],
                    from: [
                        ref(id: "toggle", carbonId: 1, keyCode: 49, characters: "Space"),
                        ref(id: "jump", carbonId: 2, keyCode: 37, characters: "L", action: .jumpToTerminal),
                    ]
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCarbonHotKeyControllerPlansRegistrationsWithStableCarbonIds() {
        let specs = [
            spec(id: "toggle", keyCode: 49),
            spec(id: "jump", keyCode: 37, action: .jumpToTerminal),
        ]

        let plan = CarbonHotKeyController().planRegistration(specs)

        XCTAssertEqual(plan.registeredHotKeys.map(\.id), ["toggle", "jump"])
        XCTAssertEqual(plan.registeredHotKeys.map(\.carbonId), [1, 2])
        XCTAssertEqual(plan.failures, [])
    }

    func testCarbonHotKeyControllerKeepsExistingRefsAndReportsRejectedRegistrations() {
        let existing = HotKeyRef(
            id: "toggle",
            carbonId: 7,
            keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
            scope: .persistentGlobal,
            action: .toggleIsland
        )

        let plan = CarbonHotKeyController().planRegistration(
            [
                spec(id: "toggle", keyCode: 49),
                spec(id: "jump", keyCode: 37, action: .jumpToTerminal),
            ],
            existingRefs: [existing],
            rejectedSpecIds: ["jump"]
        )

        XCTAssertEqual(plan.registeredHotKeys, [existing])
        XCTAssertEqual(plan.failures, [
            CarbonHotKeyRegistrationFailure(specId: "jump", reason: .registrationRejected),
        ])
    }

    func testCarbonHotKeyControllerPlansUnregistrationById() {
        let refs = [
            HotKeyRef(
                id: "toggle",
                carbonId: 1,
                keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
                scope: .persistentGlobal,
                action: .toggleIsland
            ),
            HotKeyRef(
                id: "jump",
                carbonId: 2,
                keyCombo: KeyCombo(keyCode: 37, characters: "L", modifiers: [.command]),
                scope: .persistentGlobal,
                action: .jumpToTerminal
            ),
        ]

        let plan = CarbonHotKeyController().planUnregistration(ids: ["toggle"], from: refs)

        XCTAssertEqual(plan.removedHotKeyIds, ["toggle"])
        XCTAssertEqual(plan.remainingHotKeys.map(\.id), ["jump"])
    }

    private func spec(
        id: String,
        keyCode: Int,
        characters: String = "K",
        action: ShortcutAction = .toggleIsland
    ) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: id,
            action: action,
            keyCombo: KeyCombo(keyCode: keyCode, characters: characters, modifiers: [.command]),
            scope: .persistentGlobal
        )
    }

    private func ref(
        id: String,
        carbonId: Int,
        keyCode: Int,
        characters: String,
        action: ShortcutAction = .toggleIsland
    ) -> HotKeyRef {
        HotKeyRef(
            id: id,
            carbonId: carbonId,
            keyCombo: KeyCombo(keyCode: keyCode, characters: characters, modifiers: [.command]),
            scope: .persistentGlobal,
            action: action
        )
    }
}

private struct CarbonHotKeyControllerMatrixFixture: Codable, Equatable {
    let rows: [CarbonHotKeyControllerMatrixRow]
}

private struct CarbonHotKeyControllerMatrixRow: Codable, Equatable {
    let id: String
    let registrationPlan: CarbonHotKeyRegistrationPlan?
    let unregistrationPlan: CarbonHotKeyUnregistrationPlan?

    init(
        id: String,
        registrationPlan: CarbonHotKeyRegistrationPlan? = nil,
        unregistrationPlan: CarbonHotKeyUnregistrationPlan? = nil
    ) {
        self.id = id
        self.registrationPlan = registrationPlan
        self.unregistrationPlan = unregistrationPlan
    }
}
