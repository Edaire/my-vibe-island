import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class GlobalHotKeyRuntimeTests: XCTestCase {
    func testRuntimeInstallsOnceRegistersRoutesAndRemovesEveryOwnedToken() throws {
        let system = CarbonSystemRecorder()
        var routed: [String] = []
        let runtime = MyVibeIslandAppKitCarbonHotKeyRuntime(
            onHotKey: { routed.append($0) },
            installHandler: system.install,
            removeHandler: system.removeHandler,
            registerHotKey: system.register,
            unregisterHotKey: system.unregister
        )
        let first = ref(id: "switcher", carbonID: 7, keyCode: 48, modifiers: [.command])
        let second = ref(id: "collapse", carbonID: 8, keyCode: 53, modifiers: [])

        XCTAssertTrue(runtime.register(first))
        XCTAssertTrue(runtime.register(first))
        XCTAssertTrue(runtime.register(second))
        XCTAssertEqual(system.installCount, 1)
        XCTAssertEqual(system.registrationRequests.map(\.id), ["switcher", "collapse"])
        XCTAssertEqual(runtime.registeredHotKeyIDs, ["switcher", "collapse"])

        try system.fire(carbonID: 7)
        try system.fire(carbonID: 999)
        XCTAssertEqual(routed, ["switcher"])

        runtime.stop()

        XCTAssertEqual(Set(system.unregisteredIDs), ["switcher", "collapse"])
        XCTAssertEqual(system.removeHandlerCount, 1)
        XCTAssertFalse(runtime.isHandlerInstalled)
        XCTAssertTrue(runtime.registeredHotKeyIDs.isEmpty)
    }

    func testRuntimeReportsRegistrationFailureWithoutRetainingRef() {
        let system = CarbonSystemRecorder(rejectedIDs: ["rejected"])
        let runtime = MyVibeIslandAppKitCarbonHotKeyRuntime(
            onHotKey: { _ in },
            installHandler: system.install,
            removeHandler: system.removeHandler,
            registerHotKey: system.register,
            unregisterHotKey: system.unregister
        )

        XCTAssertFalse(runtime.register(ref(id: "rejected", carbonID: 9, keyCode: 1, modifiers: [.option])))
        XCTAssertTrue(runtime.registeredHotKeyIDs.isEmpty)

        runtime.stop()
        XCTAssertEqual(system.removeHandlerCount, 1)
        XCTAssertTrue(system.unregisteredIDs.isEmpty)
    }

    func testControllerReconcilesRemovedSpecsAndRuntimeStopTearsDownHandler() {
        let system = CarbonSystemRecorder()
        var routed: [String] = []
        let runtime = MyVibeIslandAppKitCarbonHotKeyRuntime(
            onHotKey: { routed.append($0) },
            installHandler: system.install,
            removeHandler: system.removeHandler,
            registerHotKey: system.register,
            unregisterHotKey: system.unregister
        )
        let controller = MyVibeIslandAppKitCarbonHotKeyController(runtime: runtime)

        _ = controller.register([
            spec(id: "switcher", keyCode: 48, action: .toggleIsland),
            spec(id: "collapse", keyCode: 53, action: .collapsePanel),
        ])
        _ = controller.register([
            spec(id: "switcher", keyCode: 48, action: .toggleIsland),
        ])

        XCTAssertEqual(controller.refs.map(\.id), ["switcher"])
        XCTAssertEqual(system.unregisteredIDs, ["collapse"])

        controller.stop()
        XCTAssertTrue(controller.refs.isEmpty)
        XCTAssertEqual(Set(system.unregisteredIDs), ["switcher", "collapse"])
        XCTAssertEqual(system.removeHandlerCount, 1)
        XCTAssertTrue(routed.isEmpty)
    }

    private func ref(
        id: String,
        carbonID: Int,
        keyCode: Int,
        modifiers: [ModifierKeyOption]
    ) -> HotKeyRef {
        HotKeyRef(
            id: id,
            carbonId: carbonID,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: keyCode, characters: "", modifiers: modifiers),
            scope: .persistentGlobal,
            action: .toggleIsland
        )
    }

    private func spec(id: String, keyCode: Int, action: ShortcutAction) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: id,
            action: action,
            keyCombo: MyVibeIslandCore.KeyCombo(keyCode: keyCode, characters: "", modifiers: [.command]),
            scope: .persistentGlobal
        )
    }
}

@MainActor
private final class CarbonSystemRecorder {
    private(set) var installCount = 0
    private(set) var removeHandlerCount = 0
    private(set) var registrationRequests: [MyVibeIslandAppKitCarbonHotKeyRegistrationRequest] = []
    private(set) var unregisteredIDs: [String] = []
    private var callback: ((UInt32) -> Void)?
    private let rejectedIDs: Set<String>

    init(rejectedIDs: Set<String> = []) {
        self.rejectedIDs = rejectedIDs
    }

    func install(_ callback: @escaping (UInt32) -> Void) -> Any? {
        installCount += 1
        self.callback = callback
        return NSObject()
    }

    func removeHandler(_ token: Any) {
        removeHandlerCount += 1
        callback = nil
    }

    func register(_ request: MyVibeIslandAppKitCarbonHotKeyRegistrationRequest) -> Any? {
        registrationRequests.append(request)
        return rejectedIDs.contains(request.id) ? nil : NSObject()
    }

    func unregister(_ id: String, _ token: Any) {
        unregisteredIDs.append(id)
    }

    func fire(carbonID: UInt32) throws {
        try XCTUnwrap(callback)(carbonID)
    }
}
