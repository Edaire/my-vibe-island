import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitSwitcherEventMonitorTests: XCTestCase {
    func testInjectedFlagsCallbacksRouteConfiguredModifierReleaseOnlyWhileSwitcherActive() throws {
        let registrations = EventMonitorRegistrations()
        let coordinator = makeCoordinator()
        let monitor = MyVibeIslandAppKitSwitcherEventMonitor(
            coordinator: coordinator,
            modifierFlags: { .command },
            interactionFrame: { DisplayFrame(x: 10, y: 10, width: 100, height: 100) },
            registerLocal: registrations.registerLocal,
            registerGlobal: registrations.registerGlobal,
            removeMonitor: registrations.remove
        )
        monitor.start()

        XCTAssertEqual(registrations.localMask, [.flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown])
        XCTAssertEqual(registrations.globalMask, [.flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown])

        try registrations.sendLocal(flagsEvent([.command]))
        try registrations.sendLocal(flagsEvent([]))
        XCTAssertFalse(coordinator.state.isOpen)

        coordinator.open(sessionIDs: ["session"], highlighted: nil)
        try registrations.sendLocal(flagsEvent([.option]))
        try registrations.sendLocal(flagsEvent([]))
        XCTAssertTrue(coordinator.state.isOpen)

        try registrations.sendLocal(flagsEvent([.command]))
        try registrations.sendGlobal(flagsEvent([]))

        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertEqual(registrations.removedTokens.count, 2)
    }

    func testFirstFlagsEventCanReleaseModifierHeldBeforeMonitorStarted() throws {
        let registrations = EventMonitorRegistrations()
        let coordinator = makeCoordinator()
        let monitor = MyVibeIslandAppKitSwitcherEventMonitor(
            coordinator: coordinator,
            modifierFlags: { .command },
            currentModifierFlags: { .command },
            interactionFrame: { nil },
            registerLocal: registrations.registerLocal,
            registerGlobal: registrations.registerGlobal,
            removeMonitor: registrations.remove
        )
        coordinator.open(sessionIDs: ["session"], highlighted: nil)
        monitor.start()

        try registrations.sendGlobal(flagsEvent([]))

        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertFalse(monitor.isStarted)
        XCTAssertEqual(registrations.removedTokens.count, 2)
    }

    func testInjectedMouseCallbacksCollapseOnlyOutsideActiveInteractionFrame() throws {
        let registrations = EventMonitorRegistrations()
        let coordinator = makeCoordinator()
        let monitor = MyVibeIslandAppKitSwitcherEventMonitor(
            coordinator: coordinator,
            modifierFlags: { .control },
            interactionFrame: { DisplayFrame(x: 10, y: 10, width: 100, height: 100) },
            registerLocal: registrations.registerLocal,
            registerGlobal: registrations.registerGlobal,
            removeMonitor: registrations.remove
        )
        coordinator.open(sessionIDs: ["session"], highlighted: nil)
        monitor.start()

        try registrations.sendLocal(mouseEvent(.rightMouseDown, at: NSPoint(x: 50, y: 50)))
        XCTAssertTrue(coordinator.state.isOpen)

        try registrations.sendGlobal(mouseEvent(.otherMouseDown, at: NSPoint(x: 250, y: 250)))

        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertEqual(registrations.removedTokens.count, 2)
    }

    func testStartIsIdempotentAndStopRemovesEveryRetainedToken() {
        let registrations = EventMonitorRegistrations()
        let monitor = MyVibeIslandAppKitSwitcherEventMonitor(
            coordinator: makeCoordinator(),
            modifierFlags: { .shift },
            interactionFrame: { nil },
            registerLocal: registrations.registerLocal,
            registerGlobal: registrations.registerGlobal,
            removeMonitor: registrations.remove
        )

        monitor.start()
        monitor.start()

        XCTAssertEqual(registrations.localRegistrationCount, 1)
        XCTAssertEqual(registrations.globalRegistrationCount, 1)
        XCTAssertTrue(monitor.isStarted)

        monitor.stop()

        XCTAssertEqual(registrations.removedTokens.count, 2)
        XCTAssertFalse(monitor.isStarted)
    }

    private func makeCoordinator() -> MyVibeIslandAppKitSwitcherCoordinator {
        MyVibeIslandAppKitSwitcherCoordinator(
            jumpToSession: { _ in },
            routePanelInteraction: { _ in }
        )
    }

    private func flagsEvent(_ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 0
        )!
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}

@MainActor
private final class EventMonitorRegistrations {
    private(set) var localRegistrationCount = 0
    private(set) var globalRegistrationCount = 0
    private(set) var removedTokens: [ObjectIdentifier] = []
    private(set) var localMask: NSEvent.EventTypeMask = []
    private(set) var globalMask: NSEvent.EventTypeMask = []
    private var localCallback: ((MyVibeIslandAppKitSwitcherEventMonitor.Input) -> Void)?
    private var globalCallback: ((MyVibeIslandAppKitSwitcherEventMonitor.Input) -> Void)?

    func registerLocal(
        _ mask: NSEvent.EventTypeMask,
        _ callback: @escaping (MyVibeIslandAppKitSwitcherEventMonitor.Input) -> Void
    ) -> Any? {
        localRegistrationCount += 1
        localMask = mask
        localCallback = callback
        return NSObject()
    }

    func registerGlobal(
        _ mask: NSEvent.EventTypeMask,
        _ callback: @escaping (MyVibeIslandAppKitSwitcherEventMonitor.Input) -> Void
    ) -> Any? {
        globalRegistrationCount += 1
        globalMask = mask
        globalCallback = callback
        return NSObject()
    }

    func remove(_ token: Any) {
        removedTokens.append(ObjectIdentifier(token as AnyObject))
    }

    func sendLocal(_ event: NSEvent) throws {
        try XCTUnwrap(localCallback)(MyVibeIslandAppKitSwitcherEventMonitor.Input(event))
    }

    func sendGlobal(_ event: NSEvent) throws {
        try XCTUnwrap(globalCallback)(MyVibeIslandAppKitSwitcherEventMonitor.Input(event))
    }
}
