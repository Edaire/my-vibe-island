import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitCarbonHotKeyControllerTests: XCTestCase {
    @MainActor
    func testCarbonHotKeyControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CarbonHotKeyControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/carbon-hot-key-controller-matrix")
        )

        let actual = CarbonHotKeyControllerMatrixFixture(rows: [
            row(id: "register-with-rejection", initialRefs: [], specs: Self.specs, rejectedIds: ["jump"], unregisterIds: []),
            row(
                id: "unregister-matching-ref",
                initialRefs: [Self.ref(id: "toggle", carbonId: 3), Self.ref(id: "jump", carbonId: 4)],
                specs: [],
                rejectedIds: [],
                unregisterIds: ["toggle"]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRegistersSuccessfulHotKeysAndReportsRejectedSpecs() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitCarbonHotKeyController(
            registerHotKey: { ref in
                events.append("register:\(ref.id):\(ref.carbonId)")
                return ref.id != "jump"
            },
            unregisterHotKey: { ref in
                events.append("unregister:\(ref.id)")
            }
        )

        let plan = controller.register(Self.specs)

        XCTAssertEqual(plan.registeredHotKeys.map(\.id), ["toggle"])
        XCTAssertEqual(plan.failures, [
            CarbonHotKeyRegistrationFailure(specId: "jump", reason: .registrationRejected),
        ])
        XCTAssertEqual(controller.refs.map(\.id), ["toggle"])
        XCTAssertEqual(events, [
            "register:toggle:1",
            "register:jump:2"
        ])
    }

    @MainActor
    func testControllerUnregistersMatchingHotKeysAndKeepsRemainingRefs() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitCarbonHotKeyController(
            initialRefs: [
                Self.ref(id: "toggle", carbonId: 3),
                Self.ref(id: "jump", carbonId: 4),
            ],
            registerHotKey: { _ in true },
            unregisterHotKey: { ref in
                events.append("unregister:\(ref.id):\(ref.carbonId)")
            }
        )

        let plan = controller.unregister(ids: ["toggle"])

        XCTAssertEqual(plan.removedHotKeyIds, ["toggle"])
        XCTAssertEqual(plan.remainingHotKeys.map(\.id), ["jump"])
        XCTAssertEqual(controller.refs.map(\.id), ["jump"])
        XCTAssertEqual(events, ["unregister:toggle:3"])
    }

    @MainActor
    func testControllerPublishesLastCarbonPlansForOrchestration() {
        let controller = MyVibeIslandAppKitCarbonHotKeyController(
            initialRefs: [
                Self.ref(id: "toggle", carbonId: 3),
            ],
            registerHotKey: { _ in true },
            unregisterHotKey: { _ in }
        )

        let registration = controller.register(Self.specs)

        XCTAssertEqual(controller.lastRegistrationPlan, registration)

        let unregistration = controller.unregister(ids: ["toggle"])

        XCTAssertEqual(controller.lastUnregistrationPlan, unregistration)
    }

    private static let specs = [
        spec(id: "toggle", keyCode: 49, action: .toggleIsland),
        spec(id: "jump", keyCode: 37, action: .jumpToTerminal),
    ]

    private static func spec(
        id: String,
        keyCode: Int,
        action: ShortcutAction
    ) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: id,
            action: action,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: keyCode, characters: "K", modifiers: [.command]),
            scope: .persistentGlobal
        )
    }

    private static func ref(id: String, carbonId: Int) -> HotKeyRef {
        HotKeyRef(
            id: id,
            carbonId: carbonId,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: carbonId, characters: "K", modifiers: [.command]),
            scope: .persistentGlobal,
            action: .toggleIsland
        )
    }

    @MainActor
    private func row(
        id: String,
        initialRefs: [HotKeyRef],
        specs: [HotKeyRegistrationSpec],
        rejectedIds: Set<String>,
        unregisterIds: Set<String>
    ) -> CarbonHotKeyControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitCarbonHotKeyController(
            initialRefs: initialRefs,
            registerHotKey: {
                events.append("register:\($0.id):\($0.carbonId)")
                return !rejectedIds.contains($0.id)
            },
            unregisterHotKey: { events.append("unregister:\($0.id):\($0.carbonId)") }
        )
        let registration = specs.isEmpty ? nil : controller.register(specs)
        let unregistration = unregisterIds.isEmpty ? nil : controller.unregister(ids: unregisterIds)

        return CarbonHotKeyControllerMatrixRow(
            id: id,
            registeredIds: registration?.registeredHotKeys.map(\.id),
            failures: registration?.failures.map { "\($0.specId):\($0.reason.rawValue)" },
            removedIds: unregistration?.removedHotKeyIds,
            remainingIds: controller.refs.map(\.id),
            lastRegistrationIds: controller.lastRegistrationPlan?.registeredHotKeys.map(\.id),
            lastUnregistrationRemovedIds: controller.lastUnregistrationPlan?.removedHotKeyIds,
            events: events
        )
    }
}

private struct CarbonHotKeyControllerMatrixFixture: Codable, Equatable {
    let rows: [CarbonHotKeyControllerMatrixRow]
}

private struct CarbonHotKeyControllerMatrixRow: Codable, Equatable {
    let id: String
    let registeredIds: [String]?
    let failures: [String]?
    let removedIds: [String]?
    let remainingIds: [String]
    let lastRegistrationIds: [String]?
    let lastUnregistrationRemovedIds: [String]?
    let events: [String]
}
